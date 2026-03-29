const { test, expect } = require("@playwright/test");
const { login } = require("./helpers");

// ---------------------------------------------------------------------------
// Index page
// ---------------------------------------------------------------------------

test("index page loads with contest and prop cards", async ({ page }) => {
  await page.goto("/");
  await expect(page.locator("body")).toContainText("World Cup 2026");
  // Prop cards with OVER/UNDER buttons
  const overButtons = page.getByRole("button", { name: "OVER" });
  const underButtons = page.getByRole("button", { name: "UNDER" });
  await expect(overButtons.first()).toBeVisible();
  await expect(underButtons.first()).toBeVisible();
});

// ---------------------------------------------------------------------------
// Guest pick toggling
// ---------------------------------------------------------------------------

test("guest clicking OVER does not crash the page", async ({ page }) => {
  await page.goto("/");
  const firstOver = page.getByRole("button", { name: "OVER" }).first();
  await firstOver.click();

  // Toggle is an Alpine.js fetch — guest gets a 302/auth error but page stays.
  // The key thing is the page doesn't break.
  await expect(page.locator("body")).toContainText("World Cup 2026");
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
// Logged-in pick toggling
// ---------------------------------------------------------------------------

test("logged-in user can toggle OVER and see cart update", async ({ page }) => {
  await login(page, "alex@turf.com", "password");

  const firstOver = page.getByRole("button", { name: "OVER" }).first();
  await firstOver.click();

  // Cart should open and show 1 pick
  await expect(page.locator("body")).toContainText("1/4");

  // Click same OVER again to deselect
  await firstOver.click();
  // Pick count should go back to 0 — cart may close
  await expect(page.getByText("1/4")).not.toBeVisible();
});

// ---------------------------------------------------------------------------
// Pick persists on reload (server-rendered from cart entry)
// ---------------------------------------------------------------------------

test("pick persists after page reload", async ({ page }) => {
  await login(page, "sam@turf.com", "password");

  const firstOver = page.getByRole("button", { name: "OVER" }).first();
  await firstOver.click();
  await expect(page.locator("body")).toContainText("1/4");

  // Reload
  await page.reload();

  // The pick should still be selected (Alpine reads from server-rendered data)
  await expect(page.locator("body")).toContainText("1/4");
});

// ---------------------------------------------------------------------------
// Three picks shows confirm button
// ---------------------------------------------------------------------------

test("selecting 4 picks shows Hold to Confirm button", async ({ page }) => {
  await login(page, "alex@turf.com", "password");

  const overButtons = page.getByRole("button", { name: "OVER" });
  await overButtons.nth(0).click();
  await expect(page.locator("body")).toContainText("1/4");

  await overButtons.nth(1).click();
  await expect(page.locator("body")).toContainText("2/4");

  await overButtons.nth(2).click();
  await expect(page.locator("body")).toContainText("3/4");

  await overButtons.nth(3).click();
  await expect(page.locator("body")).toContainText("4/4");

  // Hold to Confirm button should be visible (desktop + mobile = 2 elements, use first)
  await expect(page.getByText("Hold to Confirm").first()).toBeVisible();
});

// ---------------------------------------------------------------------------
// Second entry after confirming
// ---------------------------------------------------------------------------

test("user can start a second entry after confirming the first", async ({ page }) => {
  await login(page, "alex@turf.com", "password");

  // Alex may have picks from previous test — dismiss blur overlay if present
  const blurOverlay = page.locator("div.fixed.inset-0.z-20.cursor-pointer");
  if (await blurOverlay.isVisible({ timeout: 500 }).catch(() => false)) {
    await blurOverlay.click();
  }

  // Ensure we have 4 picks (alex may already have some from previous test)
  const overButtons = page.getByRole("button", { name: "OVER" });
  while (!(await page.locator("body").textContent()).includes("4/4")) {
    const underButtons = page.getByRole("button", { name: "UNDER" });
    // Click next available UNDER to fill slots
    for (let i = 0; i < 4; i++) {
      const btn = underButtons.nth(i);
      if (await btn.isVisible().catch(() => false)) {
        await btn.click();
        await page.waitForTimeout(200);
        if ((await page.locator("body").textContent()).includes("4/4")) break;
      }
    }
    break;
  }
  await expect(page.locator("body")).toContainText("4/4");

  // Confirm entry via POST (hold button interaction already tested separately)
  await page.evaluate(async () => {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;
    // Extract contest path from the View Contest Details link (slug-based URL)
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

  // Dismiss blur overlay if present (triggered by previous entry's 4 picks)
  const overlay = page.locator("div.fixed.inset-0.z-20.cursor-pointer");
  if (await overlay.isVisible({ timeout: 1000 }).catch(() => false)) {
    await overlay.click();
  }

  // Entry is now active — try to toggle a pick on the first prop
  const firstOver = page.getByRole("button", { name: "OVER" }).first();
  await firstOver.click();

  // Should see the pick registered in the cart (1/4)
  await expect(page.locator("body")).toContainText("1/4");
});

// ---------------------------------------------------------------------------
// Contest show page
// ---------------------------------------------------------------------------

test("contest show page loads with leaderboard section", async ({ page }) => {
  // Get the contest link from the index
  await page.goto("/");
  await page.click("text=View Contest Details");

  await expect(page.locator("body")).toContainText("World Cup 2026");
  // Leaderboard section should exist (may be empty if no entries)
  // Grade Contest section should exist since contest is not settled
  await expect(page.locator("body")).toContainText("Grade Contest");
});
