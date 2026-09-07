const { test, expect } = require("@playwright/test");
const { reseed, login, setupPhantomMock } = require("./helpers");

// Client-side wallet failures reaching error_logs.
//
// WHY THIS NEEDS A BROWSER. Every other tier can prove a piece: the endpoint
// records (test/controllers/solana_client_failure_report_test.rb), the scrub
// holds (test/services/solana/client_failure_report_test.rb), the URL routes
// (test/controllers/wallet_failure_reporter_wiring_test.rb). None of them can
// prove the one thing that actually failed for seven production sessions — that
// a real wallet rejection, in a real Alpine component, ends with a POST leaving
// the page. The failure is caught, mapped and painted entirely client-side, so
// the browser is the only place the whole path exists.
//
// AND THE FAIL-OPEN HALF IS ONLY PROVABLE HERE. A reporting fault must not
// change one character of what the user reads. The second test breaks the
// endpoint and asserts the screen is identical — an assertion that has no
// meaning without a screen.
test.setTimeout(60_000);

test.beforeEach(async ({ request }) => await reseed(request));

// Phantom's OWN decline, verbatim: a `code` of 4001 alongside the message. Both
// halves matter downstream — the layout rethrows on either, and the modal maps
// on the code — so a mock that carried only one would exercise half the branch.
const PHANTOM_DECLINE = { code: 4001, message: "User rejected the request." };

const REPORT_PATH = "/auth/solana/report_failure";

// A wallet nobody owns. Seed byte 1 is MOCK_PUBKEY_B58, which global-setup.js
// has already pinned to the ADMIN — linking it to a fresh signup calls
// merge_users! and absorbs the admin, which global-teardown then cannot restore.
// Same constant and same reason as e2e/wallet_setup.spec.js.
const UNOWNED_WALLET_SEED = 7;

// Open the wallet-setup modal on a freshly signed-up account.
//
// FRESH, NOT THE ADMIN, and that is load-bearing rather than tidy: global-setup
// pins the admin's wallet to the mock's own address, so an admin arrives at this
// modal ALREADY LINKED. The success spec below waits on `phantomLinked` becoming
// true — against the admin that is true before the click, the wait returns
// instantly, and the spec passes having driven nothing at all. Measured here on
// 2026-09-07: it passed in 688ms with the click doing no work.
//
// Driven through the modal store rather than by walking the onboarding chain
// (e2e/wallet_setup.spec.js owns that walk) because these specs are about the
// CATCH BLOCK, and the route taken to the modal changes nothing about it.
async function openWalletSetup(page, connectError) {
  await setupPhantomMock(page, { seedByte: UNOWNED_WALLET_SEED, connectError });
  await login(page, `walletreport-${Date.now().toString(36)}@example.com`);
  await page.goto("/");
  await page.waitForFunction(() => window.Alpine && Alpine.store("modals"));

  // THE PRECONDITION, ASSERTED. A user who already holds a wallet cannot
  // exercise any of this, and the failure mode is silence, not red.
  const linked = await page.evaluate(
    () => JSON.parse(document.getElementById("session-context").textContent).phantomLinked
  );
  expect(linked).toBe(false);

  await page.evaluate(() => Alpine.store("modals").open("wallet-setup", {}));
  await expect(page.getByRole("heading", { name: "Set up your wallet" })).toBeVisible();
  // The row only becomes the Connect button once wallet_provider.js has seen the
  // injected Phantom. Waiting on the badge is waiting on that registration.
  await expect(page.getByText("Installed", { exact: true })).toBeVisible();
}

test("a declined signature is reported with BOTH the raw and mapped message", async ({ page }) => {
  await openWalletSetup(page, PHANTOM_DECLINE);

  const [request] = await Promise.all([
    page.waitForRequest((r) => r.url().includes(REPORT_PATH) && r.method() === "POST"),
    page.getByText("Installed", { exact: true }).click(),
  ]);

  const body = JSON.parse(request.postData());

  // THE PAIR IS THE POINT. `raw` is what Phantom said; `mapped` is what the user
  // read. The 2026-09-06 incident was a correct mapper meeting a wallet string
  // it had never seen — undiagnosable from the mapped half alone.
  expect(body.raw_message).toBe("User rejected the request.");
  expect(body.mapped_message).toBe("Signature rejected");
  expect(body.stage).toBe("wallet_setup_connect");
  expect(body.provider).toBe("Phantom");

  // Layer 1 of the PII rule, asserted on the WIRE. No credential key exists in
  // the body, so none can reach a proxy buffer, an access log, or a row.
  expect(Object.keys(body).sort()).toEqual([
    "mapped_message",
    "provider",
    "raw_message",
    "stage",
  ]);

  // And the user still gets their sentence.
  await expect(page.locator("p.text-red-400")).toHaveText("Signature rejected");
});

test("a 500 from the reporter leaves the sign-in flow untouched", async ({ page }) => {
  // THE FAIL-OPEN PROOF, and it is a direct one: break the endpoint, then assert
  // the screen is what it would have been anyway. An assertion that only covers
  // the happy path is not evidence of failing open.
  const pageErrors = [];
  page.on("pageerror", (error) => pageErrors.push(String(error)));

  await openWalletSetup(page, PHANTOM_DECLINE);

  let reported = false;
  await page.route(`**${REPORT_PATH}`, (route) => {
    reported = true;
    return route.fulfill({ status: 500, contentType: "text/plain", body: "boom" });
  });

  await page.getByText("Installed", { exact: true }).click();

  // 1. The user reads exactly the same sentence.
  await expect(page.locator("p.text-red-400")).toHaveText("Signature rejected");

  // 2. The modal is still theirs to retry with — `connecting` was released, so
  //    the row is not stuck in its disabled/spinner state behind a dead POST.
  await expect(page.getByText("Connecting…")).toBeHidden();
  await expect(page.getByRole("heading", { name: "Set up your wallet" })).toBeVisible();

  // 3. Nothing surfaced. A promise rejection with no `.catch` reaches the page
  //    as an unhandled rejection, which is the shape a broken fail-open takes.
  expect(pageErrors).toEqual([]);

  // 4. And the endpoint really was called and really did fail — without this the
  //    three assertions above would pass just as well if the reporter had never
  //    fired at all, which is the whole failure this task exists to fix.
  expect(reported).toBe(true);
});

test("a dead network while reporting leaves the sign-in flow untouched", async ({ page }) => {
  // THE HALF A 500 CANNOT REACH, and it went unproven until a mutant said so.
  //
  // `fetch` RESOLVES for a 500 — an HTTP error status is a successful round trip
  // — so the spec above never enters the reporter's `.catch()`. Measured
  // 2026-09-07: deleting `.catch(function() {})` from window.reportWalletFailure
  // outright left all four of the other specs GREEN. Only a transport failure
  // rejects the promise, and an unhandled rejection is precisely the shape a
  // broken fail-open takes on this surface: silent, invisible to the user, and
  // fatal to any Alpine handler that happened to be awaiting it.
  //
  // So this aborts the request instead of answering it.
  await page.addInitScript(() => {
    window.__unhandledRejections = [];
    window.addEventListener("unhandledrejection", (event) => {
      window.__unhandledRejections.push(
        String((event.reason && event.reason.message) || event.reason)
      );
    });
  });
  const pageErrors = [];
  page.on("pageerror", (error) => pageErrors.push(String(error)));

  await openWalletSetup(page, PHANTOM_DECLINE);

  let aborted = false;
  await page.route(`**${REPORT_PATH}`, (route) => {
    aborted = true;
    return route.abort("failed");
  });

  await page.getByText("Installed", { exact: true }).click();

  // 1. The user reads exactly the sentence they would have read anyway.
  await expect(page.locator("p.text-red-400")).toHaveText("Signature rejected");

  // 2. The modal is still theirs to retry with.
  await expect(page.getByText("Connecting…")).toBeHidden();
  await expect(page.getByRole("heading", { name: "Set up your wallet" })).toBeVisible();

  // 3. The transport really did fail — without this the assertions above would
  //    pass just as well if the reporter had never fired.
  expect(aborted).toBe(true);

  // 4. And the rejection was CAUGHT. This is the assertion the 500 spec cannot
  //    make: it is empty only because `.catch()` ran.
  expect(await page.evaluate(() => window.__unhandledRejections)).toEqual([]);
  expect(pageErrors).toEqual([]);
});

test("a successful connect reports nothing", async ({ page }) => {
  // The over-reporting guard. error_logs is a triage surface: a row per
  // successful sign-in would bury the failures this change exists to surface.
  await openWalletSetup(page, null);

  let reports = 0;
  page.on("request", (r) => {
    if (r.url().includes(REPORT_PATH)) reports += 1;
  });

  await page.getByText("Installed", { exact: true }).click();

  await page.waitForFunction(() => {
    const el = document.getElementById("session-context");
    return el && JSON.parse(el.textContent).phantomLinked === true;
  }, null, { timeout: 20000 });

  expect(reports).toBe(0);
});

test("the 2026-09-06 incident: an empty Phantom reports the layout's substituted string", async ({ page }) => {
  // THE INCIDENT ITSELF, replayed. Phantom is installed — so the row paints
  // "Installed" and the picker offers it — but it holds no keypair and rejects
  // with its generic 'Unexpected error'. That string used to reach
  // parseSolanaError, whose transaction branch answered with USDC balance advice
  // in a CONNECT modal. solanaConnectAndVerify now rethrows it in the vocabulary
  // of what actually failed.
  //
  // AND THE LIMIT THIS PINS, so nobody reads a row wrong: because that rethrow
  // happens in the LAYOUT, the wallet's own 'Unexpected error' is already gone by
  // the time the modal catches it. On this branch `raw` is the layout's sentence,
  // not Phantom's. A decline rethrows the original untouched (see the first test
  // above), so the common case is genuine — but this one is not, and the fix for
  // it is a report from inside solanaConnectAndVerify, which is a separate change.
  await openWalletSetup(page, { message: "Unexpected error" });

  const [request] = await Promise.all([
    page.waitForRequest((r) => r.url().includes(REPORT_PATH) && r.method() === "POST"),
    page.getByText("Installed", { exact: true }).click(),
  ]);

  const body = JSON.parse(request.postData());
  expect(body.raw_message).toContain("Finish setting up your wallet in Phantom");
  expect(body.raw_message).not.toContain("Unexpected error");

  // And the user is NOT told about their USDC balance.
  expect(body.mapped_message).not.toMatch(/USDC/i);
  await expect(page.locator("p.text-red-400")).toContainText("create or import one");
});
