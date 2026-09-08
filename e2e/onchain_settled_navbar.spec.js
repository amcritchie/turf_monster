const { test, expect } = require("@playwright/test");
const { loginViaPhantom } = require("./helpers");
const { setupPhantomMock } = require("./phantom-mock");

// THE SETTLE WINDOW, IN A REAL BROWSER (task: onchain-success-reloads-state).
//
// WHY THIS FILE HAS TO EXIST. The unit coverage for onchainSettled() executes
// solana_utils.js in NODE, against stubbed globals. That proves the module's
// logic and nothing about the PAGE: not that the layout calls
// settleOnLoadIfPending(), not that the importmap serves the module, not that
// the pill it paints is the element the navbar actually renders. Every one of
// those is a place the feature can be perfectly correct and still not run.
//
// So this asserts things only a live browser can produce: the DOM state of the
// real [data-balance-display] element, and the real number of
// /account/session_refresh requests the page issues.
//
// The bug being pinned: a read taken right after a spend can return the
// PRE-SPEND balance, because the RPC has not caught up. Measured on QA
// 2026-09-07 — a $75 contest creation, a refresh 828ms after the server
// answered, and a navbar that showed the old number for the next minute.

const SETTLE_KEY = "tm:onchain-settle-until";
const SETTLED = "1164.0";
const PILL = "[data-balance-display]";

// Serve a KNOWN settled balance and count every read the page makes.
async function stubSessionRefresh(page, counter) {
  await page.route("**/account/session_refresh", (route) => {
    counter.count += 1;
    route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
        usdc: SETTLED, usdt: "0.0", tokens: "0",
        seeds: 0, level: 1, toward_next: 0, progress: 0
      })
    });
  });
}

test.describe("on-chain settle window", () => {
  test.beforeEach(async ({ page }) => {
    await setupPhantomMock(page);
    await loginViaPhantom(page);
  });

  test("a pending settle holds the pill in loading, then paints once", async ({ page }) => {
    const reads = { count: 0 };
    await stubSessionRefresh(page, reads);

    // Arrange the state a navigating caller leaves behind. Written through the
    // page's own sessionStorage — the same store onchainSettled writes — rather
    // than by calling the function, so this exercises the HANDOFF and not just
    // the writer.
    await page.evaluate(
      ([key, until]) => window.sessionStorage.setItem(key, String(until)),
      [SETTLE_KEY, Date.now() + 4000]
    );

    const readsBeforeReload = reads.count;
    await page.reload();

    // DURING THE WINDOW — the assertion that matters. The page has loaded and
    // the layout ran, and it must NOT have read the chain, and must NOT be
    // showing a dollar figure. A String assertion cannot see either of these.
    await page.waitForTimeout(1200);
    const pill = page.locator(PILL).first();
    await expect(pill).toHaveClass(/hidden/);
    expect((await pill.textContent()).trim()).toBe("");
    expect(reads.count).toBe(readsBeforeReload);

    // AFTER — exactly one read, and the settled number on screen.
    await expect(pill).not.toHaveClass(/hidden/, { timeout: 15000 });
    await expect(pill).toHaveText(/^\$1164$/, { timeout: 15000 });
    expect(reads.count).toBe(readsBeforeReload + 1);
  });

  // ONE WRITER, IN A BROWSER. The level-up token poller calls the same
  // refreshSession() inside the settle window; review measured ~7.6s of the
  // PRE-SPEND figure presented as the answer. The stub here deliberately serves
  // the PRE-SPEND number so a too-early paint is visible — a fixture that
  // answered 1164 to everyone could not express this bug, which is how the
  // first version of this file missed it.
  test("a competing refresh cannot paint the balance mid-window", async ({ page }) => {
    await page.route("**/account/session_refresh", (route) =>
      route.fulfill({
        status: 200, contentType: "application/json",
        body: JSON.stringify({ usdc: "1239.0", usdt: "0.0", tokens: "0", seeds: 0, level: 1, toward_next: 0, progress: 0 })
      })
    );

    await page.evaluate(
      ([key, until]) => window.sessionStorage.setItem(key, String(until)),
      [SETTLE_KEY, Date.now() + 6000]
    );
    await page.reload();
    await page.waitForTimeout(1000);

    // Drive the competing read the poller would make, through the real module.
    await page.evaluate(() => window.refreshSession && window.refreshSession());
    await page.waitForTimeout(600);

    const pill = page.locator(PILL).first();
    await expect(pill).toHaveClass(/hidden/);
    expect((await pill.textContent()).trim()).toBe("");
  });

  test("a normal load with no pending settle hydrates immediately", async ({ page }) => {
    const reads = { count: 0 };
    await stubSessionRefresh(page, reads);

    // THE CONTROL. Without it, a settleOnLoadIfPending() that always returned
    // true would pass the test above while silently breaking every ordinary
    // page load — the navbar would simply never hydrate.
    await page.evaluate((key) => window.sessionStorage.removeItem(key), SETTLE_KEY);
    const before = reads.count;
    await page.reload();

    await expect(page.locator(PILL).first()).toHaveText(/^\$1164$/, { timeout: 15000 });
    expect(reads.count).toBeGreaterThan(before);
  });
});
