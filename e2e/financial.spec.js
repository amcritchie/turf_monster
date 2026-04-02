const { test, expect } = require("@playwright/test");
const { login, loginAdmin } = require("./helpers");

test.describe("Wallet & Transactions", () => {
  test("wallet page loads with balance", async ({ page }) => {
    await loginAdmin(page);
    await page.goto("/wallet");
    await expect(page.getByRole("heading", { name: "Wallet", exact: true })).toBeVisible();
    await expect(page.locator("body")).toContainText("Deposited");
    await expect(page.locator("body")).toContainText("Withdrawable");
    // Balance should show a dollar amount (don't check exact value — tests share state)
    await expect(page.locator("body")).toContainText(/\$\d+\.\d{2}/);
  });

  test("deposit adds funds", async ({ page }) => {
    await loginAdmin(page);
    await page.goto("/wallet");

    // Read balance before deposit
    const balanceBefore = await page.locator(".text-primary.font-mono").first().textContent();
    const before = parseFloat(balanceBefore.replace(/[^0-9.]/g, ""));

    // Fill deposit form and submit
    await page.fill("#deposit_amount", "5.00");
    await page.locator('button:has-text("Deposit")').click();
    await page.waitForURL("/wallet");

    // Verify success flash
    await expect(page.locator("body")).toContainText("Deposited $5.00");

    // Verify balance increased by $5
    const balanceAfter = await page.locator(".text-primary.font-mono").first().textContent();
    const after = parseFloat(balanceAfter.replace(/[^0-9.]/g, ""));
    expect(after).toBeCloseTo(before + 5, 1);
  });

  test("faucet adds $10 test USDC", async ({ page }) => {
    await loginAdmin(page);
    await page.goto("/wallet");

    // Click faucet button
    await page.locator('button:has-text("Get Test USDC")').click();
    await page.waitForURL("/wallet");

    // Verify success flash
    await expect(page.locator("body")).toContainText("Added $10.00 test USDC");
  });

  test("withdrawal creates pending request", async ({ page }) => {
    await loginAdmin(page);
    await page.goto("/wallet");

    // Fill withdraw form and submit
    await page.fill("#withdraw_amount", "2.00");
    await page.locator('button:has-text("Withdraw")').click();
    await page.waitForURL("/wallet");

    // Verify success flash and pending badge
    await expect(page.locator("body")).toContainText("submitted for review");
    await expect(page.locator("body")).toContainText("Pending review");
  });

  test("wallet shows recent transactions after deposit", async ({ page }) => {
    await loginAdmin(page);
    await page.goto("/wallet");

    // Make a deposit first
    await page.fill("#deposit_amount", "1.00");
    await page.locator('button:has-text("Deposit")').click();
    await page.waitForURL("/wallet");

    // Verify transaction appears in recent transactions
    await expect(page.locator("body")).toContainText("Recent Transactions");
    await expect(page.locator("body")).toContainText("deposit");
  });
});

test.describe("Admin Transaction Log", () => {
  test("admin can view transaction log", async ({ page }) => {
    await loginAdmin(page);

    // Make a deposit to ensure at least one transaction exists
    await page.goto("/wallet");
    await page.fill("#deposit_amount", "1.00");
    await page.locator('button:has-text("Deposit")').click();
    await page.waitForURL("/wallet");

    // Navigate to admin transactions
    await page.goto("/admin/transactions");
    await expect(page.getByRole("heading", { name: "Transaction Log" })).toBeVisible();
    await expect(page.locator("body")).toContainText("Deposits");
    await expect(page.locator("body")).toContainText("deposit");
  });

  test("admin transaction log detail page", async ({ page }) => {
    await loginAdmin(page);

    // Make a deposit
    await page.goto("/wallet");
    await page.fill("#deposit_amount", "3.00");
    await page.locator('button:has-text("Deposit")').click();
    await page.waitForURL("/wallet");

    // Navigate to admin transactions and click first description link in the table
    await page.goto("/admin/transactions");
    await page.locator("table a", { hasText: "Deposit" }).first().click();

    // Verify detail page
    await expect(page.getByRole("heading", { name: "Transaction Detail" })).toBeVisible();
    await expect(page.locator("body")).toContainText("$3.00");
    await expect(page.locator("body")).toContainText("deposit");
  });

  test("admin can filter by type", async ({ page }) => {
    await loginAdmin(page);

    // Make a deposit to ensure data exists
    await page.goto("/wallet");
    await page.fill("#deposit_amount", "1.00");
    await page.locator('button:has-text("Deposit")').click();
    await page.waitForURL("/wallet");

    // Navigate to admin transactions and click deposit filter
    await page.goto("/admin/transactions");
    await page.locator("a", { hasText: "Deposit" }).first().click();

    // URL should contain type=deposit
    await expect(page).toHaveURL(/type=deposit/);
    await expect(page.locator("body")).toContainText("deposit");
  });

  test("admin can approve withdrawal", async ({ page }) => {
    await loginAdmin(page);

    // Create a pending withdrawal
    await page.goto("/wallet");
    await page.fill("#withdraw_amount", "5.00");
    await page.locator('button:has-text("Withdraw")').click();
    await page.waitForURL("/wallet");

    // Go to admin transactions and approve
    await page.goto("/admin/transactions?status=pending");
    await expect(page.locator("body")).toContainText("pending");

    // Click approve button
    await page.locator('button:has-text("Approve")').first().click();
    await page.waitForLoadState("networkidle");

    // Verify approval notice
    await expect(page.locator("body")).toContainText("approved");
  });

  test("admin can deny withdrawal and funds are returned", async ({ page }) => {
    await loginAdmin(page);

    // Record initial balance
    await page.goto("/wallet");
    const balanceBefore = await page.locator(".text-primary.font-mono").first().textContent();
    const before = parseFloat(balanceBefore.replace(/[^0-9.]/g, ""));

    // Create a pending withdrawal
    await page.fill("#withdraw_amount", "3.00");
    await page.locator('button:has-text("Withdraw")').click();
    await page.waitForURL("/wallet");

    // Go to admin transactions and deny (accept the confirm dialog)
    await page.goto("/admin/transactions?status=pending");
    page.on("dialog", (dialog) => dialog.accept());
    await page.locator('button:has-text("Deny")').first().click();
    await page.waitForLoadState("networkidle");

    // Verify denial notice
    await expect(page.locator("body")).toContainText("denied");

    // Check funds returned — balance should be back to original
    await page.goto("/wallet");
    const balanceAfter = await page.locator(".text-primary.font-mono").first().textContent();
    const after = parseFloat(balanceAfter.replace(/[^0-9.]/g, ""));
    expect(after).toBeCloseTo(before, 1);
  });
});
