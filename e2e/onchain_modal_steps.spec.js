const { test, expect } = require("@playwright/test");
const { reseed } = require("./helpers");

// [e2e] An on-chain flow's progress steps live in ONE modal.
//
// THE BUG. `Alpine.store('modals').open()` is a stack and pushes unless told
// otherwise. `solanaModal.show()` called it once per step, so a three-step
// flow left three live entries: success() patched the top one, and dismissing
// it revealed the "Approve in Phantom" card still sitting underneath. That is
// what an operator hit on mainnet on 2026-09-07 while settling a contest, and
// it applied to all 39 show() call sites — contest ENTRY and contest CREATION
// included, where a redirect usually swallowed the evidence.
//
// WHY ONLY A BROWSER CAN SEE IT. The stack lives in Alpine's client-side store.
// Nothing about it reaches the server, appears in the response, or shows up in
// a rendered String — the page markup is byte-identical whether show() pushes
// or patches. The only witness is the running store.
//
// The second test is the one that matters most. The obvious repair here was
// $store.modals.advance(), which animates the change — but it DROPS any step
// arriving inside its ~440ms slide, and these steps are machine-driven and
// routinely closer together than that. A flow stuck on "Preparing" while
// Phantom is actually waiting is worse than the pile it replaced, so the
// stale-title case is pinned explicitly.
test.beforeEach(async ({ request }) => await reseed(request));

const stackDepth = (page) =>
  page.evaluate(() => window.Alpine.store("modals").stack.length);

const currentTitle = (page) =>
  page.evaluate(() => {
    const c = window.Alpine.store("modals").current();
    return c ? c.props.title : null;
  });

test.describe("On-chain modal steps", () => {
  test("three progress steps leave exactly one modal @smoke", async ({ page }) => {
    await page.goto("/contests");
    await page.waitForFunction(() => window.Alpine && window.Alpine.store("solanaModal"));

    await page.evaluate(() => {
      const m = window.Alpine.store("solanaModal");
      m.show("Preparing Settle Contest", "Building a fresh transaction…");
      m.show("Co-signing Settle Contest", "Approve the transaction in Phantom…");
      m.show("Confirming Onchain", "Broadcasting from the server…");
    });

    expect(await stackDepth(page)).toBe(1);
    expect(await currentTitle(page)).toBe("Confirming Onchain");
  });

  // Steps fired back-to-back with no await between them: this is the timing
  // an animated transition drops.
  test("a step fired mid-transition still wins @smoke", async ({ page }) => {
    await page.goto("/contests");
    await page.waitForFunction(() => window.Alpine && window.Alpine.store("solanaModal"));

    await page.evaluate(() => {
      const m = window.Alpine.store("solanaModal");
      m.show("Step One", "one");
      m.show("Step Two", "two");
    });
    // Well past the 440ms slide an animated implementation would have run,
    // so a dropped-then-reasserted step would have surfaced by now.
    await page.waitForTimeout(800);

    expect(await currentTitle(page)).toBe("Step Two");
    expect(await stackDepth(page)).toBe(1);
  });

  test("dismissing the resolved modal reveals nothing behind it @smoke", async ({ page }) => {
    await page.goto("/contests");
    await page.waitForFunction(() => window.Alpine && window.Alpine.store("solanaModal"));

    await page.evaluate(() => {
      const m = window.Alpine.store("solanaModal");
      m.show("Preparing", "…");
      m.show("Co-signing", "Approve the transaction in Phantom…");
      m.show("Confirming Onchain", "…");
      m.success("SiGnAtUrE", "Transaction confirmed on-chain.", { variant: "generic" });
    });

    expect(await currentTitle(page)).toBe("Confirming Onchain");
    await page.evaluate(() => window.Alpine.store("solanaModal").close());
    await page.waitForTimeout(600);

    // The whole point: no "Approve the transaction in Phantom…" card left over.
    expect(await stackDepth(page)).toBe(0);
  });

  // A step resets the transient props, so a retry after a failure never opens
  // showing the previous attempt's error.
  test("a step after an error clears the stale error @smoke", async ({ page }) => {
    await page.goto("/contests");
    await page.waitForFunction(() => window.Alpine && window.Alpine.store("solanaModal"));

    const state = await page.evaluate(() => {
      const m = window.Alpine.store("solanaModal");
      m.show("Co-signing", "Approve…");
      m.error("Broadcast failed", "Settle Contest Failed");
      m.show("Co-signing", "Approve…");
      const c = window.Alpine.store("modals").current();
      return { state: c.props.state, error: c.props.errorMessage, depth: window.Alpine.store("modals").stack.length };
    });

    expect(state.state).toBe("processing");
    expect(state.error).toBeNull();
    expect(state.depth).toBe(1);
  });
});
