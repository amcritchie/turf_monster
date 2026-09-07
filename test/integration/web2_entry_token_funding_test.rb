require "test_helper"

# Web2 entry-token funding — a web2 / managed player who lacks funds at the entry
# blocker now buys an ENTRY TOKEN (the Buy an Entry Token modal: Coinflow buy-1 on
# top, the Stripe pack picker below) instead of the USDC Top Up Wallet. Web3 wallet
# players are UNCHANGED (still the Coinbase-forward USDC Top Up Wallet).
#
# The audience split is a single client dispatcher, selectionBoard#showFundsNeeded,
# that every funds-needed reroute (the no_funding blocker, the hold-window check,
# the chain-layer "no entry token" twin) funnels through. These assert the wiring
# at the render boundary — the modal registration, both rails, the dispatcher, and
# that web3's showWalletTopup path is intact. The live Alpine handoff is a tracked
# Playwright e2e gap (same precedent as wallet_topup_test + the on-chain success
# modal). Companion to wallet_topup_test.rb.
class Web2EntryTokenFundingTest < ActionDispatch::IntegrationTest
  # --- modal registration (ungated, like wallet-topup / onramp-hub) ---

  test "the buy-entry-token modal is registered ungated in the layout for a guest" do
    get contests_path
    assert_response :success
    assert_includes response.body, "$store.modals.current().id === 'buy-entry-token'",
                     "buy-entry-token must be registered in the layout (ungated, like wallet-topup)"
    assert_includes response.body, "Buy an Entry Token"
  end

  test "the buy-entry-token modal stays registered when logged in as a web2 user" do
    log_in_as users(:jordan)
    get contests_path
    assert_response :success
    assert_includes response.body, "$store.modals.current().id === 'buy-entry-token'"
    assert_includes response.body, "Buy an Entry Token"
    # A magic-link login is a web2 session — the audience this modal serves.
    assert_includes response.body, %("mode":"web2")
  end

  # --- the two stacked rails: Coinflow on top, Stripe below ---

  test "the modal renders the Coinflow buy-1 rail wired to tmCoinflowBuyOne('single')" do
    get contests_path
    assert_response :success
    body = response.body
    assert_includes body, %(data-buy-rail="coinflow")
    assert_includes body, "tmCoinflowBuyOne('single')"
    # 1 token = 1 entry framing + the modal's own subtitle.
    assert_includes body, "pick how to pay"
    # The Coinflow kickoff script is present so the button works.
    assert_includes body, "window.tmCoinflowBuyOne = async function"
  end

  test "the modal renders the Stripe pack-picker rail, swapping into the auth wizard" do
    get contests_path
    assert_response :success
    body = response.body
    assert_includes body, %(data-buy-rail="stripe")
    assert_includes body,
                    "$store.modals.swap('auth', { step: 'tokens-picker', mintedCount: 0, mintedBalance: 0, errorText: '', redirectUrl: '', txSignature: '' })"
  end

  test "the Coinflow rail renders ABOVE the Stripe rail (link on top, button below)" do
    get contests_path
    assert_response :success
    body = response.body
    coinflow_at = body.index(%(data-buy-rail="coinflow"))
    stripe_at   = body.index(%(data-buy-rail="stripe"))
    assert coinflow_at, "the Coinflow rail must render"
    assert stripe_at,   "the Stripe rail must render"
    assert coinflow_at < stripe_at,
           "the Coinflow rail must render above the Stripe rail (Coinflow first)"
  end

  # --- the audience dispatcher: web2 -> buy-entry-token, web3 -> wallet-topup ---

  test "showFundsNeeded sends the funds wall to Get USDC, keeping only the kill-switch audience on tokens" do
    get contest_path(contests(:one))
    assert_response :success
    body = response.body
    assert_includes body, "showFundsNeeded() {"
    # REBOUND (2026-09-05). The old assertion pinned `mode === 'web2'` as the
    # whole condition — the fork that sent every web2 player to a modal with no
    # visible rails in production. What must hold now: the USDC card is the
    # default answer, and the ONLY audience still routed to tokens is the one
    # that literally cannot pay with USDC (ENABLE_WEB2_USDC_ENTRY off).
    assert_includes body, "session.mode === 'web2' && !session.web2UsdcEntry"
    assert_includes body, "this.showBuyEntryToken();"
    assert_includes body, "this.showGetUsdc();"
    # showBuyEntryToken must refuse to open with no rail to show, rather than
    # painting "pick how to pay" over an empty box.
    assert_includes body, "if (!Alpine.store('session').entryTokenRailsAvailable) {"
    # showBuyEntryToken opens the buy-entry-token modal (open vs swap, like wallet-topup).
    assert_includes body, "showBuyEntryToken() {"
    assert_includes body, "s.open('buy-entry-token', { enterAnim: 'shake' })"
    assert_includes body, "s.swap('buy-entry-token', {})"
  end

  test "every funds-needed reroute funnels through showFundsNeeded" do
    get contest_path(contests(:one))
    assert_response :success
    body = response.body
    # The no_funding eligibility-blocker case routes through the dispatcher.
    assert_match(/case 'no_funding':\s+this\.showFundsNeeded\(\);/, body,
                 "the no_funding entry wall must route through showFundsNeeded")
    # Exactly the three funds-needed reroutes call the dispatcher (the no_funding
    # blocker, the hold-window fundable:false abort, and the chain-layer twin).
    # showFundsNeeded's own body calls showBuyEntryToken / showWalletTopup, not
    # itself, so it never inflates the count.
    assert_equal 3, body.scan("this.showFundsNeeded();").size,
                 "all three funds-needed reroutes must funnel through showFundsNeeded"
  end

  # --- web3 unchanged: showWalletTopup + the USDC Top Up Wallet are intact ---

  test "Top Up Wallet is still REACHABLE, not merely still defined" do
    get contest_path(contests(:one))
    assert_response :success
    body = response.body
    # REBOUND. "unchanged" was proved by the presence of the function's source
    # text, which stays true after its last caller disappears — and that is
    # exactly what happened for one revision. The property worth defending is
    # that a player can still GET there.
    assert_includes body, "showWalletTopup() {"
    assert_includes body, "$store.modals.current().id === 'wallet-topup'"
    assert_includes body, "$store.modals.swap('wallet-topup', {})",
                    "the Get USDC card must carry the onward control into Top Up Wallet"

    # The Coinbase CTA inside that modal is NOT part of its reachability, and
    # asserting it on this page pinned the defect: cdp-ramp is registered behind
    # logged_in? AND ENABLE_CDP_RAMP, neither of which holds for the guest render
    # above, so the CTA used to render here with no modal to open. Ask for it on
    # a page that actually registers the modal.
    refute_includes body, "Buy USDC with Coinbase",
                    "the CTA must not outlive the cdp-ramp modal on a guest page"

    with_env("ENABLE_CDP_RAMP" => "true") do
      log_in_as users(:jordan)
      get contest_path(contests(:one))
    end
    assert_response :success
    assert_includes response.body, "Buy USDC with Coinbase"
    assert_includes response.body, "$store.modals.current().id === 'cdp-ramp'"
  end

  # --- the empty-rails guard, with its FALSE branch actually run --------------
  #
  # Review found this guard had never executed. entryTokenRailsAvailable mirrors
  # the only two rails _buy_entry_token renders, but onramp_helper.rb opens
  # `return true unless Rails.env.production?`, so outside production every rail
  # is visible and the flag can only ever be true. The assertion that existed was
  # an assert_includes of the literal `if` line — it proved the branch was WRITTEN,
  # not that it works.
  #
  # Fake production the way the onramp helper's own tests do, turn both rails off,
  # and read the server's answer out of the payload the board branches on.
  # (The JS branch itself still wants an e2e; this closes the server half, which
  # is the half that decides.)
  def in_production(&block) = Rails.env.stub(:production?, true, &block)

  def session_context_flag(body, key)
    json = body[/<script type="application\/json" id="session-context">(.*?)<\/script>/m, 1]
    JSON.parse(json).fetch(key)
  end

  test "entryTokenRailsAvailable goes FALSE when neither entry-token rail is visible" do
    with_env("ENABLE_COINFLOW" => nil, "PAYMENT_PROVIDER" => nil) do
      in_production do
        get contest_path(contests(:one))
        assert_response :success
        refute session_context_flag(response.body, "entryTokenRailsAvailable"),
               "with Coinflow unset and Stripe not the provider, the entry-token " \
               "modal has no rail to show — the flag must say so, or showBuyEntryToken " \
               "opens 'pick how to pay' over an empty box (prod, 2026-09-05)"
      end
    end
  end

  test "and TRUE as soon as one rail comes back" do
    with_env("ENABLE_COINFLOW" => "true", "PAYMENT_PROVIDER" => nil) do
      in_production do
        get contest_path(contests(:one))
        assert_response :success
        assert session_context_flag(response.body, "entryTokenRailsAvailable"),
               "one visible rail is enough to keep the entry-token modal open-able"
      end
    end
  end

  def with_env(pairs)
    originals = pairs.keys.to_h { |k| [k, ENV[k]] }
    pairs.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    yield
  ensure
    originals.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end
end
