// The mobile wallet guard, in a real browser.
//
// WHAT THIS TIER ADDS. test/lib/wallet_require_provider_js_test.rb drives the
// same module under node and owns the copy rules; test/integration/
// wallet_stub_parity_test.rb proves the inlined stub agrees with it. Neither can
// answer whether the module ARRIVES — whether the importmap actually delivers
// wallet_provider.js to a real page and the method is reachable there. A pin
// dropped from importmap.rb, an asset that 404s, a syntax error a node eval
// tolerated: each leaves the page throwing "requireProvider is not a function"
// with both other tiers still green.
//
// And it is the only tier that sees a browser with genuinely no wallet, which is
// every phone that is not inside a wallet app's own browser.
const { test, expect } = require("@playwright/test");

const IPHONE =
  "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1";

// Ask the REAL page's module what it does with no wallet present. Returns the
// thrown message rather than asserting inside the page, so a failure reports the
// sentence a user would have seen.
async function refusal(page) {
  return page.evaluate(() => {
    try {
      window.walletProvider.requireProvider();
      return { threw: false };
    } catch (e) {
      return { threw: true, message: e.message, isMobile: window.walletProvider.isMobile() };
    }
  });
}

test.describe("wallet guard on a device with no wallet", () => {
  test.describe("on a phone", () => {
    test.use({ userAgent: IPHONE });

    test("refuses with the wallet-app remedy, not a null dereference @smoke", async ({ page }) => {
      await page.goto("/");
      // Poll on get(), NOT requireProvider(): this change MIRRORS
      // requireProvider into the inlined stub, so polling on it is satisfied
      // by the stub and every assertion below would pass with the importmap
      // pin deleted — the one failure this tier claims to be the only one to
      // catch. get() exists only on the module.
      await expect
        .poll(() => page.evaluate(() => typeof window.walletProvider?.get))
        .toBe("function");

      const result = await refusal(page);

      expect(result.threw).toBe(true);
      expect(result.isMobile).toBe(true);

      // THE REGRESSION, asserted directly: this is the string a production user
      // saw in a transaction modal on 2026-09-07.
      expect(result.message).not.toMatch(/is not an object/i);
      expect(result.message).not.toMatch(/\bnull\b/i);

      // And the remedy has to be one a phone can act on.
      expect(result.message).toMatch(/wallet app/i);
      expect(result.message).not.toMatch(/install/i);
      expect(result.message).not.toMatch(/extension/i);
    });
  });

  test("a desktop browser gets extension advice instead", async ({ page }) => {
    await page.goto("/");
    await expect
      .poll(() => page.evaluate(() => typeof window.walletProvider?.get))
      .toBe("function");

    const result = await refusal(page);

    expect(result.threw).toBe(true);
    expect(result.isMobile).toBe(false);
    expect(result.message).toMatch(/extension/i);
  });
});
