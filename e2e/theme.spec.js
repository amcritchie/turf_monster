const { test, expect } = require("@playwright/test");

// ---------------------------------------------------------------------------
// Theme toggle (dark/light mode)
// ---------------------------------------------------------------------------

test("dark mode is default", async ({ page }) => {
  await page.goto("/");
  const html = page.locator("html");
  await expect(html).toHaveClass(/dark/);

  // Background should be dark navy
  const bgColor = await page.evaluate(() =>
    getComputedStyle(document.body).backgroundColor
  );
  expect(bgColor).not.toBe("rgb(248, 250, 252)"); // not slate-50 (light)
});

test("toggle to light mode", async ({ page }) => {
  await page.goto("/");
  await page.evaluate(() => localStorage.removeItem("theme"));
  await page.reload();
  await page.waitForFunction(() => window.Alpine, null, { timeout: 10_000 });

  // Click theme toggle
  await page.click('button[title="Toggle theme"]');

  // Dark class removed
  await expect(page.locator("html")).not.toHaveClass(/dark/);

  // localStorage updated
  const theme = await page.evaluate(() => localStorage.getItem("theme"));
  expect(theme).toBe("light");
});

test("light mode persists on reload", async ({ page }) => {
  await page.goto("/");
  await page.waitForFunction(() => window.Alpine, null, { timeout: 10_000 });

  // Toggle to light
  await page.click('button[title="Toggle theme"]');
  await expect(page.locator("html")).not.toHaveClass(/dark/);

  // Reload
  await page.reload();

  // Still light
  await expect(page.locator("html")).not.toHaveClass(/dark/);
  const theme = await page.evaluate(() => localStorage.getItem("theme"));
  expect(theme).toBe("light");
});

test("toggle back to dark", async ({ page }) => {
  await page.goto("/");
  await page.waitForFunction(() => window.Alpine, null, { timeout: 10_000 });

  // Toggle to light
  await page.click('button[title="Toggle theme"]');
  await expect(page.locator("html")).not.toHaveClass(/dark/);

  // Toggle back to dark
  await page.click('button[title="Toggle theme"]');
  await expect(page.locator("html")).toHaveClass(/dark/);

  const theme = await page.evaluate(() => localStorage.getItem("theme"));
  expect(theme).toBe("dark");
});
