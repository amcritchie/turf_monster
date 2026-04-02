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

module.exports = { login, loginAdmin };
