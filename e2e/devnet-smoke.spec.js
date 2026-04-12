// @ts-check
const { test, expect } = require("@playwright/test");
const { setupKeypairProvider, BOT_PUBKEY } = require("./keypair-provider");

/**
 * Devnet smoke test — exercises the full Web3 flow against real devnet.
 *
 * Prerequisites:
 *   - SOLANA_BOT_KEY env var set to Alex Bot's base58-encoded private key
 *   - Alex Bot wallet funded with ~0.1 SOL + ~$20 USDC on devnet
 *   - Test server seeded with SOLANA_BOT_PUBKEY=<bot pubkey>
 *
 * Run:
 *   SOLANA_BOT_KEY=<key> npx playwright test --grep @devnet
 */

const CONTEST_PATH = "/contests/world-cup-2026";

// ---------------------------------------------------------------------------
// Helper: select 5 matchup cards on the contest show page
// ---------------------------------------------------------------------------

async function selectFiveMatchups(page) {
  const cards = page.locator("button.bg-surface");

  for (let i = 0; i < 5; i++) {
    // Dismiss blur overlay if it appears (after picking enough)
    const blurOverlay = page.locator("div.fixed.inset-0.z-20.cursor-pointer");
    if (await blurOverlay.isVisible({ timeout: 300 }).catch(() => false)) {
      await blurOverlay.click();
    }

    await cards.nth(i).click();
    await expect(page.locator("body")).toContainText(`${i + 1}/5`);
  }
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
// @devnet: Full flow — login, contest page, pick 5, confirm entry
// ---------------------------------------------------------------------------

test("@devnet full flow: wallet login → pick 5 → submit onchain entry", async ({
  page,
}) => {
  // Inject KeypairProvider with Alex Bot's private key
  await setupKeypairProvider(page);

  // 1. Login via wallet signature
  await loginViaKeypair(page);

  // Verify logged in — username should appear in nav
  await expect(page.locator('a[href="/account"]').first()).toContainText(
    "alex"
  );

  // 2. Navigate to contest page
  await page.goto(CONTEST_PATH);
  await expect(page.locator("body")).toContainText("World Cup 2026");

  // 3. Select 5 matchups
  await selectFiveMatchups(page);

  // Verify cart shows 5/5
  await expect(page.locator("body")).toContainText("5/5");

  // 4. Hold to confirm — triggers onchain entry flow
  // The hold button requires a 2-second hold. For onchain contests with wallet,
  // early_action fires at 1.5s and starts the confirm flow immediately.
  const holdBtn = page.locator(".hold-btn").first();
  await holdBtn.scrollIntoViewIfNeeded();

  // Simulate hold by mouse down for 2.5s
  const box = await holdBtn.boundingBox();
  if (!box) throw new Error("Hold button not visible");
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  await page.mouse.down();

  // Wait for the Solana modal to appear (shows "Sign Entry" or "Preparing Transaction")
  await expect(
    page.locator('text="Sign Entry"').or(page.locator('text="Preparing Transaction"'))
  ).toBeVisible({ timeout: 10000 });

  // Release hold
  await page.mouse.up();

  // 5. Wait for the full onchain flow to complete (devnet can be slow)
  // Success state shows "Entry submitted onchain" with a tx signature
  await expect(page.locator('text="Entry submitted onchain"')).toBeVisible({
    timeout: 60000,
  });

  // Verify tx signature link is present (links to Solana Explorer)
  const explorerLink = page.locator('a[href*="explorer.solana.com"]');
  await expect(explorerLink).toBeVisible({ timeout: 5000 });

  // Extract and log the tx signature for manual verification
  const href = await explorerLink.getAttribute("href");
  console.log(`Devnet tx: ${href}`);
});

// ---------------------------------------------------------------------------
// @devnet: Wallet login only (quick sanity check)
// ---------------------------------------------------------------------------

test("@devnet wallet login via KeypairProvider", async ({ page }) => {
  await setupKeypairProvider(page);
  await loginViaKeypair(page);

  // Verify logged in
  await expect(page.locator('a[href="/account"]').first()).toContainText(
    "alex"
  );
  await expect(page.locator('a[href="/login"]')).not.toBeVisible();
});
