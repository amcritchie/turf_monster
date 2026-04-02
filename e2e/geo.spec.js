const { test, expect } = require("@playwright/test");
const { loginAdmin } = require("./helpers");

test.describe("Geo Settings", () => {
  test("geo settings page loads for admin", async ({ page }) => {
    await loginAdmin(page);
    await page.goto("/admin/geo");
    await expect(page.getByRole("heading", { name: "Geo Settings" })).toBeVisible();
    await expect(page.locator("body")).toContainText("Current Detection");
    await expect(page.locator("body")).toContainText("Configuration");
    await expect(page.locator("body")).toContainText("Banned States");
  });

  test("admin can toggle geo override on", async ({ page }) => {
    await loginAdmin(page);
    await page.goto("/admin/geo");

    // Click "Simulate WA" button on the geo page (the .btn one, not the navbar dropdown)
    await page.locator("button.btn:has-text('Simulate WA')").click();
    await page.waitForLoadState("networkidle");

    // Verify notice
    await expect(page.locator("body")).toContainText("Simulating WA");
  });

  test("admin can clear geo override", async ({ page }) => {
    await loginAdmin(page);
    await page.goto("/admin/geo");

    // Toggle on first
    await page.locator("button.btn:has-text('Simulate WA')").click();
    await page.waitForLoadState("networkidle");

    // After toggle ON, the page should show "Simulating WA" notice
    await expect(page.locator("body")).toContainText("Simulating WA");

    // Now the override is active — find the "Clear GEO Override" button (has btn-danger class)
    await page.locator("button.btn-danger:has-text('Clear GEO Override')").click();
    await page.waitForLoadState("networkidle");

    // Verify cleared
    await expect(page.locator("body")).toContainText("GEO override cleared");
  });

  test("geo badge shows in navbar when logged in", async ({ page }) => {
    await loginAdmin(page);
    // The navbar should show a geo state badge (could be "??" if no geo detected in test)
    const badge = page.locator("span.font-mono.rounded-full", { hasText: /[A-Z]{2}|\?\?/ });
    await expect(badge.first()).toBeVisible();
  });

  test("blocked state prevents wallet deposit", async ({ page }) => {
    await loginAdmin(page);

    // Enable geoblocking
    await page.goto("/admin/geo");
    await page.getByRole("checkbox", { name: "Enable Geo-Blocking" }).check();
    await page.locator('input[value="Save Settings"]').click();
    await page.waitForLoadState("networkidle");
    await expect(page.locator("body")).toContainText("Geo settings updated");

    // Simulate WA state — click the .btn on the geo page (not the navbar dropdown)
    await page.locator("button.btn-outline:has-text('Simulate WA')").click();
    await page.waitForLoadState("networkidle");
    await expect(page.locator("body")).toContainText("Simulating WA");

    // Try to deposit — should be blocked
    await page.goto("/wallet");
    await page.fill("#deposit_amount", "1.00");
    await page.locator('button:has-text("Deposit")').click();
    await page.waitForLoadState("networkidle");

    // Should see restriction alert (redirected to root with alert)
    await expect(page.locator("body")).toContainText("not available in your state");

    // Clean up: clear geo override
    await page.goto("/admin/geo");
    await page.locator("button.btn-danger:has-text('Clear GEO Override')").click();
    await page.waitForLoadState("networkidle");

    // Disable geoblocking
    await page.goto("/admin/geo");
    await page.getByRole("checkbox", { name: "Enable Geo-Blocking" }).uncheck();
    await page.locator('input[value="Save Settings"]').click();
    await page.waitForLoadState("networkidle");
  });
});
