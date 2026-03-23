/**
 * Log in via the login form.
 * Waits for redirect back to root after successful login.
 */
async function login(page, email, password) {
  await page.goto("/login");
  await page.fill('input[name="email"]', email);
  await page.fill('input[name="password"]', password);
  await page.click('input[type="submit"], button[type="submit"]');
  await page.waitForURL("/");
}

module.exports = { login };
