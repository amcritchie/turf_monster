const { setupPhantomMock, MOCK_PUBKEY_B58 } = require("./phantom-mock");
const { setupOnchainMocks, computeMockTransaction } = require("./rpc-mock");

/**
 * Log in via the login form.
 * Waits for redirect back to root after successful login.
 */
async function login(page, email, password) {
  await page.goto("/login");
  await page.fill('input[name="email"]', email);
  await page.fill('input[name="password"]', password);
  await page.locator('form button.btn-primary[type="submit"]').click();
  await page.waitForURL("/");
}

/**
 * Log in as admin user (alex@turf.com).
 */
async function loginAdmin(page) {
  await login(page, "alex@turf.com", "password");
}

/**
 * Log in via Phantom wallet mock.
 * Requires setupPhantomMock(page) to have been called first.
 * Clicks "Connect Wallet" on the login page and waits for redirect.
 */
async function loginViaPhantom(page) {
  await page.goto("/login");
  await page.locator('button:has-text("Connect Wallet")').click();
  await page.waitForURL("/");
}

module.exports = {
  login,
  loginAdmin,
  loginViaPhantom,
  setupPhantomMock,
  MOCK_PUBKEY_B58,
  setupOnchainMocks,
  computeMockTransaction,
};
