require "test_helper"

# [component] The Get USDC card — the teaching half of the funds wall.
#
# Two contracts worth a test, and neither is visual.
#
# 1. IT IS BUILT FROM ENGINE BLOCKS. The card it is modelled on,
#    modals/_wallet_setup, hand-rolled its close mark for eight months while
#    blocks/_close_x homed the identical mark for eight other modals. A copy
#    reads fine and drifts silently, so pin that this one composes the primitive.
# 2. THE PLAYER IS OPTIONAL. The operator supplies the video after this ships
#    (BUY_USDC_VIDEO_ID). With none configured the band must render its heading
#    and its guide and simply have no player — an embed with an empty id renders
#    YouTube's own error card inside the modal instead.
class BuyUsdcModalTest < ActionView::TestCase
  helper BuyUsdcHelper

  def with_video_id(id)
    was = ENV["BUY_USDC_VIDEO_ID"]
    ENV["BUY_USDC_VIDEO_ID"] = id
    yield
  ensure
    ENV["BUY_USDC_VIDEO_ID"] = was
  end

  # ActionView::TestCase#rendered ACCUMULATES across calls, so a refute read off
  # it would pass vacuously against the union of every render in the file. Use
  # the return value.
  def render_card
    render partial: "modals/buy_usdc"
  end

  # --- the host contract ------------------------------------------------------

  test "renders a single root element, as its x-if host requires" do
    html = with_video_id(nil) { render_card }
    roots = Nokogiri::HTML5.fragment(html).element_children

    # The layout wraps this partial in <template x-if>, which keeps exactly one
    # child. A sibling of the root is dropped silently — the failure is a modal
    # missing a piece, with nothing raised anywhere.
    assert_equal 1, roots.length,
                 "a second root element would be dropped by the host's template x-if"
    assert_includes roots.first["class"].to_s, "relative",
                    "blocks/_close_x is absolutely positioned and anchors to this root"
  end

  # --- adoption of the engine primitives --------------------------------------

  test "closes with the engine mark, not a local copy of it" do
    html = with_video_id(nil) { render_card }
    close = Nokogiri::HTML5.fragment(html).at_css("button[aria-label='Close']")

    assert close, "the card must offer a close mark"
    # The three details blocks/_close_x carries that the hand-rolled copies in
    # this app did not: an explicit type, the -mt-2 nudge onto the card corner,
    # and the z-10 that keeps it above a rail row. Asserting them is what makes
    # a silent revert to a bespoke button fail here.
    assert_equal "button", close["type"]
    assert_includes close["class"], "z-10"
    assert_includes close["class"], "-mt-2"
  end

  test "the CTA is a Phantom row that opens Phantom" do
    html = with_video_id(nil) { render_card }
    doc  = Nokogiri::HTML5.fragment(html)
    row  = doc.at_css("[data-usdc-rail='phantom']")

    assert row, "the card must offer the Phantom row"
    # A REAL LINK: it navigates off-site, and rail_row's own contract says a rail
    # that must navigate should be an anchor rather than a button.
    assert_equal "a", row.name, "a navigating CTA is an anchor, not a button"
    assert row["href"].to_s.start_with?("https://phantom."),
           "the row must point at Phantom itself"
    assert_equal "noopener noreferrer", row["rel"],
                 "an off-site tab opened from a modal must not leak window.opener"

    # The brand mark is an engine sprite symbol, and the sprite has to be INSIDE
    # this partial's single root or the host's template x-if drops it and the
    # icon renders empty with nothing raised.
    assert row.at_css('use[href="#se-wallet-phantom"]'), "the row wears the Phantom mark"

    # ASSERT THE DEFINITION, NOT THE STRING. The row's own <use href> contains
    # "se-wallet-phantom", so a substring check here passes with the sprite
    # deleted — measured: removing the render left all seven tests green. Only
    # the <symbol id> is proof the sprite actually shipped in this root.
    assert doc.at_css('symbol[id="se-wallet-phantom"]'),
           "the brand sprite must ship inside the same root as the row, or the " \
           "host's template x-if drops it and the icon renders empty"
  end

  test "Coinbase leads, because it funds the wallet the entry is paid from" do
    html = with_video_id(nil) { render_card }
    doc  = Nokogiri::HTML5.fragment(html)
    rail = doc.at_css("[data-usdc-rail='coinbase']")

    # THE REGRESSION THIS PINS. A revision of this card shipped the Phantom row
    # ALONE. A web2 entry is paid from web2_solana_address by the managed keypair,
    # and since #556 the web2 branch is exactly the managed-only population — so
    # the card's only control told them to fund a wallet their entry cannot spend
    # from. The CDP ramp follows User#solana_address, which for those accounts IS
    # the paying wallet, so this rail must lead.
    assert rail, "the Coinbase rail must render"
    assert_includes rail.to_html, "swap('cdp-ramp'"

    coinbase_at = html.index(%(data-usdc-rail="coinbase"))
    phantom_at  = html.index(%(data-usdc-rail="phantom"))
    assert phantom_at, "the Phantom row stays — it is right for a different audience"
    assert coinbase_at < phantom_at, "Coinbase must render above Phantom"
  end

  test "Top Up Wallet keeps an entrance from this card" do
    html = with_video_id(nil) { render_card }

    # showFundsNeeded was showWalletTopup's ONLY caller. Replacing the fork
    # orphaned it, taking the kill-switch degrade and the Add Funds hub with it.
    # This control is what un-orphans it, so assert the ROUTE, not the function.
    assert Nokogiri::HTML5.fragment(html).at_css("[data-usdc-more]"),
           "the card must carry the onward control into Top Up Wallet"
    assert_includes html, "$store.modals.swap('wallet-topup', {})"
  end

  # --- the optional player ----------------------------------------------------

  test "no configured video still renders the teaching band and its guide" do
    html = with_video_id(nil) { render_card }
    doc  = Nokogiri::HTML5.fragment(html)

    assert_nil doc.at_css("iframe"),
               "an embed with no id renders YouTube's error card inside the modal"
    assert_includes html, "New to USDC", "the band's heading survives an absent video"
    assert doc.at_css("[data-usdc-guide]"),
           "the read-it-instead route is the whole band when there is no player"
  end

  test "a configured video mounts the player on the privacy host" do
    html = with_video_id("abc123XYZ_-") { render_card }
    frame = Nokogiri::HTML5.fragment(html).at_css("iframe")

    assert frame, "a configured id must actually mount a player"
    assert frame["src"].start_with?("https://www.youtube-nocookie.com/embed/abc123XYZ_-"),
           "the player must come from the CSP-allowed privacy host"
    assert_includes frame["allow"].to_s, "autoplay",
                    "muted autoplay is the only autoplay a modal that opened " \
                    "without a click is permitted"
  end

  test "the unmute affordance ships with the player and not without it" do
    with_player = with_video_id("abc123XYZ_-") { render_card }
    without     = with_video_id(nil) { render_card }

    assert Nokogiri::HTML5.fragment(with_player).at_css("button[aria-label='Unmute the video']"),
           "a silent autoplaying player needs the tap-for-sound overlay"
    assert_nil Nokogiri::HTML5.fragment(without).at_css("button[aria-label='Unmute the video']"),
               "an unmute control over no player is a button that does nothing"
  end
end
