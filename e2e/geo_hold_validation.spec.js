const { test, expect } = require("@playwright/test");

// Login using dev database credentials.
// Note: reuses existing dev server (reuseExistingServer in config), so uses dev DB users.
async function doLogin(page) {
  await page.goto("/login");
  await page.waitForLoadState("domcontentloaded");

  // Dismiss SSO blur overlay if present
  const blurOverlay = page.locator("text=Click to show other options");
  if (await blurOverlay.isVisible({ timeout: 500 }).catch(() => false)) {
    await blurOverlay.click();
    await page.waitForTimeout(600);
  }

  await page.fill('input[name="email"]', "alex@mcritchie.studio");
  await page.fill('input[name="password"]', "password");
  await page.locator('button[type="submit"]:has-text("Log In")').click();
  await page.waitForTimeout(2000);

  if (page.url().includes("/login")) {
    throw new Error("Login failed — still on login page");
  }
}

// Enable geo blocking with WA banned + activate WA override via admin UI
async function enableGeoBlockingAndOverride(page) {
  await page.goto("/admin/geo");
  await page.waitForLoadState("networkidle");

  // Enable geo-blocking checkbox
  const enabledCheckbox = page.locator("#geo_setting_enabled");
  if (await enabledCheckbox.count() > 0 && !(await enabledCheckbox.isChecked())) {
    await enabledCheckbox.check({ force: true });
  }

  // WA state checkbox (hidden input — force-check via JS)
  await page.evaluate(() => {
    const waInput = document.querySelector(
      'input[value="WA"][name="geo_setting[banned_states][]"]'
    );
    if (waInput && !waInput.checked) waInput.checked = true;
  });

  // Save settings
  await page.locator('input[value="Save Settings"]').click();
  await page.waitForTimeout(2000);

  // Toggle WA override
  await page.goto("/admin/geo");
  await page.waitForLoadState("networkidle");

  const simBtn = page.getByRole("button", { name: /Simulate WA/i });
  if (await simBtn.isVisible({ timeout: 2000 }).catch(() => false)) {
    await simBtn.click();
    await page.waitForTimeout(2000);
  }
  // If "Clear GEO Override" is visible instead, override is already active
}

// ---------------------------------------------------------------------------
// Test 1: Verify /geo/check endpoint returns blocked when WA override active
// ---------------------------------------------------------------------------

test("geo/check returns blocked:true when geo enabled + WA override", async ({ page }) => {
  await doLogin(page);
  await enableGeoBlockingAndOverride(page);

  const response = await page.evaluate(async () => {
    const res = await fetch("/geo/check", {
      headers: { Accept: "application/json" },
    });
    return res.json();
  });

  expect(response.state).toBe("WA");
  expect(response.blocked).toBe(true);
});

// ---------------------------------------------------------------------------
// Test 2: Hold-to-confirm aborts at 1s with geo blocked modal
// ---------------------------------------------------------------------------

test("hold-to-confirm aborts at 1s with geo blocked modal", async ({ page }) => {
  await doLogin(page);
  await enableGeoBlockingAndOverride(page);

  // Verify geo check endpoint returns blocked
  const geoCheck = await page.evaluate(async () => {
    const res = await fetch("/geo/check", {
      headers: { Accept: "application/json" },
    });
    return res.json();
  });
  expect(geoCheck.blocked).toBe(true);

  // Select 5 matchups
  await page.goto("/");
  await page.waitForLoadState("networkidle");

  const cards = page.locator("button.bg-surface");
  const cardCount = await cards.count();
  for (let i = 0; i < Math.min(5, cardCount); i++) {
    await cards.nth(i).click({ force: true });
    await page.waitForTimeout(300);
  }
  await expect(page.locator("body")).toContainText("5/5");

  // Hold the confirm button
  const holdBtn = page.locator('.hold-btn[data-hold-id="desktop"]');
  await expect(holdBtn).toBeVisible();
  await holdBtn.dispatchEvent("mousedown");

  // Wait for mid-hold validation to fire (validate_at=1000ms + network time)
  await page.waitForTimeout(2500);

  // Validation should abort hold — "Location Restricted" modal visible
  await expect(page.getByText("Location Restricted")).toBeVisible({ timeout: 3000 });
  await expect(holdBtn).toHaveClass(/error/);

  await holdBtn.dispatchEvent("mouseup");
});
