const { test, expect } = require("@playwright/test");
const { login } = require("./helpers");

// ---------------------------------------------------------------------------
// Index page
// ---------------------------------------------------------------------------

test("index page loads with contest and matchup cards", async ({ page }) => {
  await page.goto("/");
  await expect(page.locator("body")).toContainText("Pick 5 Teams");
  // Matchup cards rendered as buttons with team names
  const matchupCards = page.locator("button.bg-surface");
  await expect(matchupCards.first()).toBeVisible();
  // Should show multiplier values
  await expect(page.locator("body")).toContainText("x1");
});

// ---------------------------------------------------------------------------
// Guest selection toggling
// ---------------------------------------------------------------------------

test("guest clicking matchup card does not crash the page", async ({ page }) => {
  await page.goto("/");
  const firstCard = page.locator("button.bg-surface").first();
  await firstCard.click();

  // Toggle is an Alpine.js fetch — guest gets a 302/auth error but page stays.
  await expect(page.locator("body")).toContainText("Pick 5 Teams");
});

// ---------------------------------------------------------------------------
// Login flow
// ---------------------------------------------------------------------------

test("login with valid credentials", async ({ page }) => {
  await login(page, "alex@turf.com", "password");
  // User name should appear in header
  await expect(page.locator("body")).toContainText("Alex");
});

test("login with invalid credentials shows error", async ({ page }) => {
  await page.goto("/login");
  await page.fill('input[name="email"]', "alex@turf.com");
  await page.fill('input[name="password"]', "wrong");
  await page.click('input[type="submit"], button[type="submit"]');
  // Should stay on login page with error
  await expect(page.locator("body")).toContainText(/invalid|incorrect/i);
});

// ---------------------------------------------------------------------------
// Logged-in selection toggling
// ---------------------------------------------------------------------------

test("logged-in user can toggle selection and see cart update", async ({ page }) => {
  await login(page, "alex@turf.com", "password");

  const firstCard = page.locator("button.bg-surface").first();
  await firstCard.click();

  // Cart should show 1 selection
  await expect(page.locator("body")).toContainText("1/5");

  // Click same card again to deselect
  await firstCard.click();
  // Selection count should go back to 0
  await expect(page.getByText("1/5")).not.toBeVisible();
});

// ---------------------------------------------------------------------------
// Selection persists on reload (server-rendered from cart entry)
// ---------------------------------------------------------------------------

test("selection persists after page reload", async ({ page }) => {
  await login(page, "sam@turf.com", "password");

  const firstCard = page.locator("button.bg-surface").first();
  await firstCard.click();
  await expect(page.locator("body")).toContainText("1/5");

  // Reload
  await page.reload();

  // The selection should still be there (Alpine reads from server-rendered data)
  await expect(page.locator("body")).toContainText("1/5");
});

// ---------------------------------------------------------------------------
// Five selections shows confirm button
// ---------------------------------------------------------------------------

test("selecting 5 matchups shows Hold to Confirm button", async ({ page }) => {
  await login(page, "alex@turf.com", "password");

  const cards = page.locator("button.bg-surface");

  await cards.nth(0).click();
  await expect(page.locator("body")).toContainText("1/5");

  await cards.nth(1).click();
  await expect(page.locator("body")).toContainText("2/5");

  await cards.nth(2).click();
  await expect(page.locator("body")).toContainText("3/5");

  await cards.nth(3).click();
  await expect(page.locator("body")).toContainText("4/5");

  // Dismiss blur overlay before clicking 5th
  const blurOverlay = page.locator("div.fixed.inset-0.z-20.cursor-pointer");
  if (await blurOverlay.isVisible({ timeout: 500 }).catch(() => false)) {
    await blurOverlay.click();
  }

  await cards.nth(4).click();
  await expect(page.locator("body")).toContainText("5/5");

  // Hold to Confirm button should be visible (desktop + mobile = 2 elements, use first)
  await expect(page.getByText("Hold to Confirm").first()).toBeVisible();
});

// ---------------------------------------------------------------------------
// Second entry after confirming
// ---------------------------------------------------------------------------

test("user can start a second entry after confirming the first", async ({ page }) => {
  await login(page, "alex@turf.com", "password");

  // Dismiss blur overlay if present
  const blurOverlay = page.locator("div.fixed.inset-0.z-20.cursor-pointer");
  if (await blurOverlay.isVisible({ timeout: 500 }).catch(() => false)) {
    await blurOverlay.click();
  }

  // Ensure we have 5 selections
  const cards = page.locator("button.bg-surface");
  for (let i = 0; i < 6; i++) {
    const bodyText = await page.locator("body").textContent();
    if (bodyText.includes("5/5")) break;
    const card = cards.nth(i);
    if (await card.isVisible().catch(() => false)) {
      await card.click();
      await page.waitForTimeout(200);
    }
  }
  await expect(page.locator("body")).toContainText("5/5");

  // Confirm entry via POST (hold button interaction already tested separately)
  await page.evaluate(async () => {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;
    const link = document.querySelector('a[href*="/contests/"]');
    const contestPath = link.getAttribute("href").match(/\/contests\/[^/]+/)[0];
    await fetch(`${contestPath}/enter`, {
      method: "POST",
      headers: { "X-CSRF-Token": csrfToken, "Accept": "application/json" },
    });
  });

  // Reload to get fresh page state after confirm
  await page.goto("/");
  await page.waitForLoadState("networkidle");

  // Dismiss blur overlay if present
  const overlay = page.locator("div.fixed.inset-0.z-20.cursor-pointer");
  if (await overlay.isVisible({ timeout: 1000 }).catch(() => false)) {
    await overlay.click();
  }

  // Try to toggle a selection on a matchup card
  const firstCard = page.locator("button.bg-surface").first();
  await firstCard.click();

  // Should see the selection registered in the cart (1/5)
  await expect(page.locator("body")).toContainText("1/5");
});

// ---------------------------------------------------------------------------
// Contest show page
// ---------------------------------------------------------------------------

test("contest show page loads with leaderboard section", async ({ page }) => {
  await page.goto("/");
  await page.click("text=View Contest Details");

  await expect(page.locator("body")).toContainText("World Cup 2026");
  // Contest details should be visible
  await expect(page.locator("body")).toContainText("Entry Fee");
});
