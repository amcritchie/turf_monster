const { test, expect } = require("@playwright/test");

// ---------------------------------------------------------------------------
// Page navigation — verify key pages load without errors
// ---------------------------------------------------------------------------

test("teams page loads", async ({ page }) => {
  await page.goto("/teams");
  await expect(page.locator("body")).toBeVisible();
  // Should have some team content from seeds
  await expect(page.locator("body")).toContainText(/team/i);
});

test("games page loads", async ({ page }) => {
  await page.goto("/games");
  await expect(page.locator("body")).toBeVisible();
});

test("login page loads with form", async ({ page }) => {
  await page.goto("/login");
  await expect(page.locator('input[name="email"]')).toBeVisible();
  await expect(page.locator('input[name="password"]')).toBeVisible();
});

test("signup page loads with form", async ({ page }) => {
  await page.goto("/signup");
  await expect(page.locator('#user_email')).toBeVisible();
  await expect(page.locator('#user_password')).toBeVisible();
});

test("error logs page loads", async ({ page }) => {
  await page.goto("/error_logs");
  await expect(page.locator("body")).toBeVisible();
});

test("turf totals page loads", async ({ page }) => {
  await page.goto("/turf-totals-v1");
  await expect(page.locator("body")).toBeVisible();
});
