// @ts-check
const { test, expect } = require("@playwright/test");
const { execSync } = require("child_process");
const { setupKeypairProvider, BOT_PUBKEY } = require("./keypair-provider");

// All rails runner commands must target the test DB (Playwright webServer uses RAILS_ENV=test)
const RUNNER_OPTS = { cwd: process.cwd(), timeout: 15000, stdio: "pipe", env: { ...process.env, RAILS_ENV: "test" } };

/**
 * Devnet smoke tests — exercise the full Web3 flow against real devnet.
 *
 * Prerequisites:
 *   - SOLANA_BOT_KEY env var set to Alex Bot's base58-encoded private key
 *   - Alex Bot wallet funded with ~0.2 SOL + ~$50 USDC on devnet
 *   - Test server seeded with SOLANA_BOT_PUBKEY=<bot pubkey>
 *
 * Run:
 *   SOLANA_BOT_KEY=<key> npx playwright test --project=devnet
 */

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const RPC_URL = process.env.SOLANA_RPC_URL || "https://api.devnet.solana.com";
const USDC_MINT = "222Dcu2RgAXE3T8A4mGSG3kQyXaNjqePx7vva1RdWBN9";
const MIN_SOL = 0.1;
const MIN_USDC = 50;

// Mack's wallet (Web3 registration tests 5-6)
const MACK_KEY = "2miFBu2EGS6vZscu31GZcXc7WZew1bHG786HRX1nA4RTohyjfLmWVpsV7Vjdgc9wCajyTd4hkFY7T4HsqgAZkmFB";
const MACK_PUBKEY = "foUuRyeibadQoGdKXZ9pBGDqmkb1jY1jYsu8dZ29nds";

// Shared state across tests (serial execution)
let sharedContestUrl;
let masonEmail;
let masonPassword;

// Balance snapshots — captured before/after for consumption tracking
let preflightSOL = 0;
let preflightUSDC = 0;

// Original wallet addresses — saved in beforeAll, restored in afterAll
let alexOriginalWallet = null;
let mackOriginalWallet = null;

// ---------------------------------------------------------------------------
// RPC helpers
// ---------------------------------------------------------------------------

async function rpcCall(method, params) {
  const res = await fetch(RPC_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
  });
  const json = await res.json();
  if (json.error) throw new Error(`RPC ${method}: ${json.error.message}`);
  return json.result;
}

async function getSOLBalance(pubkey = BOT_PUBKEY) {
  const result = await rpcCall("getBalance", [pubkey]);
  return result.value / 1e9;
}

async function getUSDCBalance(pubkey = BOT_PUBKEY) {
  const result = await rpcCall("getTokenAccountsByOwner", [
    pubkey,
    { mint: USDC_MINT },
    { encoding: "jsonParsed" },
  ]);
  if (result.value && result.value.length > 0) {
    return result.value[0].account.data.parsed.info.tokenAmount.uiAmount || 0;
  }
  return 0;
}

// ---------------------------------------------------------------------------
// Pre-flight: validate env + snapshot balances
// ---------------------------------------------------------------------------

test.beforeAll(async () => {
  // 1. SOLANA_BOT_KEY must be set
  if (!process.env.SOLANA_BOT_KEY) {
    throw new Error(
      "SOLANA_BOT_KEY env var is required. Set it to Alex Bot's base58 private key."
    );
  }

  // 2. Save original wallets, swap alex to bot key, clear Mack's wallet for fresh registration
  try {
    const saveScript = [
      `alex = User.find_by(email: 'alex@turf.com')`,
      `mack = User.find_by(username: 'mack')`,
      `puts alex&.web3_solana_address.to_s`,
      `puts mack&.web3_solana_address.to_s`,
    ].join("; ");
    const result = execSync(`bin/rails runner "${saveScript}"`, RUNNER_OPTS);
    const lines = result.toString().trim().split("\n");
    alexOriginalWallet = lines[0] || null;
    mackOriginalWallet = lines[1] || null;
    console.log(`Pre-flight — alex original wallet: ${alexOriginalWallet || "(none)"}`);
    console.log(`Pre-flight — mack original wallet: ${mackOriginalWallet || "(none)"}`);

    const script = [
      `pub = '${BOT_PUBKEY}'`,
      `User.where(web3_solana_address: pub).update_all(web3_solana_address: nil)`,
      `u = User.find_by(email: 'alex@turf.com')`,
      `u.update_column(:web3_solana_address, pub) if u`,
      `User.where(web3_solana_address: '${MACK_PUBKEY}').update_all(web3_solana_address: nil)`,
    ].join("; ");
    execSync(`bin/rails runner "${script}"`, RUNNER_OPTS);
    console.log(`Pre-flight — alex wallet linked to ${BOT_PUBKEY}`);
    console.log(`Pre-flight — mack wallet cleared (${MACK_PUBKEY})`);
  } catch (e) {
    console.warn(`Pre-flight — wallet link failed: ${e.message}`);
  }

  // 3. Snapshot balances
  preflightSOL = await getSOLBalance();
  preflightUSDC = await getUSDCBalance();

  const mackSOL = await getSOLBalance(MACK_PUBKEY);
  const mackUSDC = await getUSDCBalance(MACK_PUBKEY);

  console.log("┌─────────────────────────────────────┐");
  console.log("│         PRE-FLIGHT BALANCES          │");
  console.log("├─────────────────────────────────────┤");
  console.log(`│  Alex SOL:  ${preflightSOL.toFixed(4).padStart(9)} SOL          │`);
  console.log(`│  Alex USDC: $${preflightUSDC.toFixed(2).padStart(8)}              │`);
  console.log(`│  Mack SOL:  ${mackSOL.toFixed(4).padStart(9)} SOL          │`);
  console.log(`│  Mack USDC: $${mackUSDC.toFixed(2).padStart(8)}              │`);
  console.log("└─────────────────────────────────────┘");

  // 4. Fail fast if insufficient
  if (preflightSOL < MIN_SOL) {
    throw new Error(
      `Insufficient SOL: ${preflightSOL.toFixed(4)} < ${MIN_SOL}. ` +
        `Top up with: devnet-pow mine --target-lamports ${MIN_SOL * 1e9} -ud`
    );
  }
  if (preflightUSDC < MIN_USDC) {
    throw new Error(
      `Insufficient USDC: $${preflightUSDC.toFixed(2)} < $${MIN_USDC}. ` +
        `Top up via /faucet or CLI mint.`
    );
  }
});

// ---------------------------------------------------------------------------
// Post-flight: snapshot balances + log consumption
// ---------------------------------------------------------------------------

test.afterAll(async () => {
  // Clean up test-created users and restore original wallet addresses
  try {
    const cleanupScript = [
      // Clear wallets from any test-created users (avoids unique constraint on restore)
      `User.where(web3_solana_address: '${BOT_PUBKEY}').where.not(email: 'alex@turf.com').update_all(web3_solana_address: nil)`,
      `User.where(web3_solana_address: '${MACK_PUBKEY}').where.not(username: 'mack').update_all(web3_solana_address: nil)`,
      // Restore alex's original wallet
      alexOriginalWallet
        ? `User.find_by(email: 'alex@turf.com')&.update_column(:web3_solana_address, '${alexOriginalWallet}')`
        : null,
      // Restore mack's original wallet
      mackOriginalWallet
        ? `User.find_by(username: 'mack')&.update_column(:web3_solana_address, '${mackOriginalWallet}')`
        : null,
    ].filter(Boolean).join("; ");
    execSync(`bin/rails runner "${cleanupScript}"`, RUNNER_OPTS);
    if (alexOriginalWallet) console.log(`Post-flight — alex wallet restored to ${alexOriginalWallet}`);
    if (mackOriginalWallet) console.log(`Post-flight — mack wallet restored to ${mackOriginalWallet}`);
  } catch (e) {
    console.warn(`Post-flight — wallet restore failed: ${e.message}`);
  }

  const postSOL = await getSOLBalance();
  const postUSDC = await getUSDCBalance();
  const postMackSOL = await getSOLBalance(MACK_PUBKEY);
  const postMackUSDC = await getUSDCBalance(MACK_PUBKEY);
  const deltaSOL = postSOL - preflightSOL;
  const deltaUSDC = postUSDC - preflightUSDC;

  console.log("┌─────────────────────────────────────┐");
  console.log("│        POST-FLIGHT BALANCES          │");
  console.log("├─────────────────────────────────────┤");
  console.log(`│  Alex SOL:  ${postSOL.toFixed(4).padStart(9)} SOL          │`);
  console.log(`│  Alex USDC: $${postUSDC.toFixed(2).padStart(8)}              │`);
  console.log(`│  Mack SOL:  ${postMackSOL.toFixed(4).padStart(9)} SOL          │`);
  console.log(`│  Mack USDC: $${postMackUSDC.toFixed(2).padStart(8)}              │`);
  console.log("├─────────────────────────────────────┤");
  console.log("│           CONSUMPTION                │");
  console.log("├─────────────────────────────────────┤");
  console.log(`│  Alex SOL:  ${deltaSOL.toFixed(4).padStart(9)} SOL          │`);
  console.log(`│  Alex USDC: $${deltaUSDC.toFixed(2).padStart(8)}              │`);
  console.log("└─────────────────────────────────────┘");
});

// ---------------------------------------------------------------------------
// Helper: select the first available slate in the contest form
// ---------------------------------------------------------------------------

async function selectFirstSlate(page) {
  const options = page.locator("#contest_slate_id option:not([value=''])");
  const first = await options.first().getAttribute("value");
  await page.selectOption("#contest_slate_id", first);
}

// ---------------------------------------------------------------------------
// Helper: log in via KeypairProvider wallet connect
// ---------------------------------------------------------------------------

async function loginViaKeypair(page) {
  await page.goto("/login");
  await page.locator('button:has-text("Connect Wallet")').click();
  await page.waitForURL("/", { timeout: 30000 });
}

// ---------------------------------------------------------------------------
// Helper: select 5 matchup cards
// ---------------------------------------------------------------------------

async function selectFiveMatchups(page, startIndex = 0) {
  const cards = page.locator("button.bg-surface");

  for (let i = 0; i < 5; i++) {
    const blurOverlay = page.locator("div.fixed.inset-0.z-20.cursor-pointer");
    if (await blurOverlay.isVisible({ timeout: 300 }).catch(() => false)) {
      await blurOverlay.click();
    }

    await cards.nth(startIndex + i).click();
    await expect(page.locator("body")).toContainText(`${i + 1}/5`);
  }
}

// ---------------------------------------------------------------------------
// Helper: confirm entry via Alpine's confirmEntry() method
// ---------------------------------------------------------------------------

async function confirmEntry(page) {
  await page.evaluate(async () => {
    const els = document.querySelectorAll("[x-data]");
    for (const el of els) {
      const data = Alpine.$data(el);
      if (typeof data.confirmEntry === "function") {
        await data.confirmEntry();
        return;
      }
    }
    throw new Error("confirmEntry() not found on any Alpine component");
  });

  await expect(page.locator("body")).toContainText("Entry submitted onchain", {
    timeout: 60000,
  });
}

// ===========================================================================
// Test 1: New Contest Flow
// ===========================================================================

test("@devnet 1 — new contest flow: wallet login → create contest → pick 5 → submit entry", async ({
  page,
}) => {
  await setupKeypairProvider(page);

  // 1. Login via wallet signature
  await loginViaKeypair(page);
  await expect(page.locator('a[href="/account"]').first()).toContainText(
    "alex"
  );

  // 2. Create a real onchain contest via the form
  const contestName = `Smoke ${Date.now().toString(36)}`;
  await page.goto("/contests/new");
  await page.fill("#contest_name", contestName);
  await selectFirstSlate(page);

  await page.getByRole("button", { name: "Create Contest" }).click();
  await page.waitForURL(/\/contests\/(?!new)/, { timeout: 90000 });

  // Verify we're on the new contest page
  await expect(page.locator("body")).toContainText(contestName);
  const contestUrl = page.url();
  sharedContestUrl = contestUrl;
  console.log(`Test 1 — created onchain contest: ${contestUrl}`);

  // 3. Select 5 matchups
  await page.goto(contestUrl);
  await page.waitForLoadState("networkidle");
  await selectFiveMatchups(page);
  await expect(page.locator("body")).toContainText("5/5");

  // 4. Submit onchain entry
  await confirmEntry(page);

  // Verify tx signature link in the success modal
  const explorerLink = page.locator(
    'a[href*="explorer.solana.com/tx"]'
  ).last();
  await expect(explorerLink).toBeVisible({ timeout: 5000 });

  const href = await explorerLink.getAttribute("href");
  console.log(`Test 1 — entry tx: ${href}`);
});

// ===========================================================================
// Test 2: New Entry Submission (Mason enters Test 1's contest)
// ===========================================================================

test("@devnet 2 — new entry submission: Mason picks 5 → enters shared contest", async ({
  page,
}) => {
  test.skip(!sharedContestUrl, "No shared contest URL from Test 1");

  // Mason logs in via email/password (registered in Test 2)
  // Since Test 2 creates a unique email each run, we re-register a fresh Mason
  const ts = Date.now().toString(36);
  const email = `mason-entry-${ts}@test.com`;
  const password = "password123";

  await page.goto("/signup");
  await page.fill("#user_email", email);
  await page.fill("#user_password", password);
  await page.fill("#user_password_confirmation", password);
  await page.getByRole("button", { name: "Sign Up", exact: true }).click();
  await page.waitForURL("**/account/complete_profile", { timeout: 30000 });

  // Complete profile
  const username = `mason-e-${ts}`;
  await page.fill("#user_username", username);
  await page.getByRole("button", { name: "Save Profile" }).click();
  await page.waitForURL(/^(?!.*complete_profile)/, { timeout: 15000 });

  // Mason's balance is on-chain USDC — funded via faucet mint in beforeAll or during test
  masonEmail = email;
  masonPassword = password;
  console.log(`Test 2 —Mason registered: ${email}`);

  // Navigate to shared contest, pick 5, enter
  await page.goto(sharedContestUrl);
  await page.waitForLoadState("networkidle");

  await selectFiveMatchups(page);

  // Managed wallet: confirmEntry() posts to /enter and redirects (no onchain modal)
  await page.evaluate(async () => {
    const els = document.querySelectorAll("[x-data]");
    for (const el of els) {
      const data = Alpine.$data(el);
      if (typeof data.confirmEntry === "function") {
        await data.confirmEntry();
        return;
      }
    }
    throw new Error("confirmEntry() not found on any Alpine component");
  });

  // Wait for redirect back to the contest page (managed wallet entries redirect)
  await page.waitForURL(/\/contests\//, { timeout: 60000 });
  await page.waitForLoadState("networkidle");
  console.log("Test 2 —Mason entry submitted");

  // Verify Mason's entry appears on the contest page
  await expect(page.locator("body")).toContainText("Leaderboard", { timeout: 10000 });
  console.log("Test 2 —leaderboard visible, entry confirmed");
});

// ===========================================================================
// Test 3: Second Entry Submission (Mason re-enters with different picks)
// ===========================================================================

test("@devnet 3 — second entry submission: Mason re-enters with different picks", async ({
  page,
}) => {
  test.skip(!sharedContestUrl, "No shared contest URL from Test 1");
  test.skip(!masonEmail, "No Mason credentials from Test 2");

  // 1. Login as Mason (existing user from Test 3)
  await page.goto("/login");
  await page.fill('input[name="email"]', masonEmail);
  await page.fill('input[name="password"]', masonPassword);
  await page.locator('form button.btn-primary[type="submit"]').click();
  await page.waitForURL(/^(?!.*login)/, { timeout: 15000 });
  console.log(`Test 3 —logged in as ${masonEmail}`);

  // 2. Mason's balance is on-chain USDC — no DB top-up needed

  // 3. Navigate to shared contest with add_entry=true to show board for second entry
  await page.goto(sharedContestUrl + "?add_entry=true");
  await page.waitForLoadState("networkidle");

  // Pick different 5 matchups (cards 5-9) to avoid sybil check
  await selectFiveMatchups(page, 5);

  // 4. Managed wallet: confirmEntry() posts to /enter and redirects
  await page.evaluate(async () => {
    const els = document.querySelectorAll("[x-data]");
    for (const el of els) {
      const data = Alpine.$data(el);
      if (typeof data.confirmEntry === "function") {
        await data.confirmEntry();
        return;
      }
    }
    throw new Error("confirmEntry() not found on any Alpine component");
  });

  await page.waitForURL(/\/contests\//, { timeout: 60000 });
  await page.waitForLoadState("networkidle");

  await expect(page.locator("body")).toContainText("Leaderboard", { timeout: 10000 });
  console.log("Test 3 —Mason second entry submitted, leaderboard visible");
});

// ===========================================================================
// Test 4: New Web3 Registration (Mack via wallet connect)
// ===========================================================================

test("@devnet 4 — new web3 registration: Mack wallet connect → complete profile", async ({
  page,
}) => {
  await setupKeypairProvider(page, MACK_KEY);

  // 1. Connect wallet — creates a new user since we cleared Mack's address in beforeAll
  await page.goto("/login");
  await page.locator('button:has-text("Connect Wallet")').click();

  // May redirect to "/" or "/account/complete_profile" depending on whether profile is complete
  await page.waitForURL(/^(?!.*login)/, { timeout: 30000 });

  // 2. Complete profile if needed
  if (page.url().includes("complete_profile")) {
    const ts = Date.now().toString(36);
    await page.fill("#user_username", `mack-${ts}`);
    await page.getByRole("button", { name: "Save Profile" }).click();
    await page.waitForURL(/^(?!.*complete_profile)/, { timeout: 15000 });
    console.log("Test 4 —profile completed");
  }

  // 3. Verify logged in — account link should be visible
  await page.goto("/account");
  await expect(page.locator("body")).toContainText(MACK_PUBKEY.slice(0, 8), {
    timeout: 10000,
  });
  console.log(`Test 4 —Mack registered via wallet: ${MACK_PUBKEY}`);
});

// ===========================================================================
// Test 5: New Web3 Submission (Mack enters shared contest)
// ===========================================================================

test("@devnet 5 — new web3 submission: Mack picks 5 → enters shared contest onchain", async ({
  page,
}) => {
  test.skip(!sharedContestUrl, "No shared contest URL from Test 1");

  await setupKeypairProvider(page, MACK_KEY);

  // 1. Login via wallet (Mack exists from Test 5)
  await loginViaKeypair(page);
  console.log("Test 5 —Mack logged in via wallet");

  // 2. Navigate to shared contest, pick 5 matchups
  await page.goto(sharedContestUrl);
  await page.waitForLoadState("networkidle");
  await selectFiveMatchups(page);

  // 3. Web3 wallet: confirmEntry() goes through direct onchain path
  await confirmEntry(page);

  // 4. Verify tx signature link
  const explorerLink = page.locator(
    'a[href*="explorer.solana.com/tx"]'
  ).last();
  await expect(explorerLink).toBeVisible({ timeout: 5000 });

  const href = await explorerLink.getAttribute("href");
  console.log(`Test 5 —Mack entry tx: ${href}`);
});

// ===========================================================================
// Test 6: Web3 Second Entry (Mack re-enters with different picks)
// ===========================================================================

test("@devnet 6 — web3 second entry: Mack re-enters shared contest with different picks", async ({
  page,
}) => {
  test.skip(!sharedContestUrl, "No shared contest URL from Test 1");

  await setupKeypairProvider(page, MACK_KEY);

  // 1. Login via wallet (Mack exists from Test 5)
  await loginViaKeypair(page);
  console.log("Test 6 —Mack logged in via wallet");

  // 2. Navigate to shared contest with add_entry=true to show board for second entry
  await page.goto(sharedContestUrl + "?add_entry=true");
  await page.waitForLoadState("networkidle");

  // Pick different 5 matchups (cards 5-9) to avoid sybil check
  await selectFiveMatchups(page, 5);

  // 3. Web3 wallet: direct onchain path
  await confirmEntry(page);

  // 4. Verify tx signature link
  const explorerLink = page.locator(
    'a[href*="explorer.solana.com/tx"]'
  ).last();
  await expect(explorerLink).toBeVisible({ timeout: 5000 });

  const href = await explorerLink.getAttribute("href");
  console.log(`Test 6 —Mack second entry tx: ${href}`);
});

// ===========================================================================
// Test 7: Faucet Flow (standalone — last to avoid blocking other tests)
// ===========================================================================

test("@devnet 7 — faucet flow: signup → claim $50 USDC → verify balance", async ({
  page,
}) => {
  const ts = Date.now().toString(36);
  const email = `faucet-${ts}@test.com`;
  const password = "password123";

  // 1. Register via email/password
  await page.goto("/signup");
  await page.fill("#user_email", email);
  await page.fill("#user_password", password);
  await page.fill("#user_password_confirmation", password);
  await page.getByRole("button", { name: "Sign Up", exact: true }).click();
  await page.waitForURL("**/account/complete_profile", { timeout: 30000 });

  const username = `faucet-${ts}`;
  await page.fill("#user_username", username);
  await page.getByRole("button", { name: "Save Profile" }).click();
  await page.waitForURL(/^(?!.*complete_profile)/, { timeout: 15000 });
  console.log(`Test 7 — registered: ${email}`);

  // 2. Navigate to faucet and claim $50 USDC
  // Wait for Sidekiq to process EnsureAtaJob (creates the token account)
  await page.waitForTimeout(5000);
  await page.goto("/faucet");
  await page.waitForLoadState("networkidle");

  await page.getByRole("button", { name: "$50", exact: true }).click();
  await page.getByRole("button", { name: "Claim $50 Test USDC" }).click();

  // Wait for the Solana modal to show success (devnet can be slow)
  await expect(page.locator("body")).toContainText("Minted", { timeout: 90000 });
  console.log("Test 7 — faucet claim successful");

  // Close the modal
  await page.locator('button:has-text("Done")').click();

  // 3. Verify balance on wallet page
  await page.goto("/wallet");
  await page.waitForLoadState("networkidle");
  await expect(page.locator("body")).toContainText("$50.00");
  console.log("Test 7 — wallet balance verified at $50.00");
});
