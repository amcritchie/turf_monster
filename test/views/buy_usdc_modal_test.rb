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

  test "the card offers Phantom and NOTHING resembling a payment rail" do
    html = with_video_id(nil) { render_card }
    doc  = Nokogiri::HTML5.fragment(html)

    assert doc.at_css("[data-usdc-rail='phantom']"), "Phantom is the route"

    # THE CDP/COINBASE ONRAMP HAS NO LEGAL CLEARANCE (operator, 2026-09-06). A
    # revision of this card led with that rail. Leading a funds wall with an
    # uncleared payment path is the one mistake here that is not a layout
    # problem, so pin its absence — including the indirect routes, since
    # _wallet_topup and _onramp_hub both still offer it.
    refute_includes html, "cdp-ramp", "the uncleared onramp must not be reachable"
    refute_includes html, "wallet-topup", "nor reachable one hop away through Top Up Wallet"
    refute_includes html, "onramp-hub", "nor through the Add Funds hub"
    refute_includes html, "Coinbase", "and it must not be named"
  end

  test "the Phantom row tries to open the wallet, and keeps the link as its floor" do
    html = with_video_id(nil) { render_card }
    row  = Nokogiri::HTML5.fragment(html).at_css("[data-usdc-rail='phantom']")

    assert_includes row.to_html, "openPhantom($event)",
                    "tapping the row must reach for the installed wallet"
    # THE HREF IS THE FLOOR, not decoration: openPhantom returns WITHOUT
    # preventDefault when no provider exists, so a visitor with no Phantom still
    # navigates somewhere useful instead of tapping a dead row.
    assert row["href"].to_s.start_with?("https://phantom."),
           "no-provider case must still navigate"
  end

  test "the already-connected case says so instead of looking dead" do
    html = with_video_id(nil) { render_card }

    # Phantom auto-approves a trusted site and opens NOTHING, and no web API can
    # force an extension popup. At this wall the user is usually already
    # connected, so this is the common path, not an edge case.
    assert_includes html, "prov.isConnected",
                    "the already-connected state must be detected, not assumed away"
    assert_includes html, "open it from your browser toolbar",
                    "and must tell the user the one thing that actually works"
    assert Nokogiri::HTML5.fragment(html).at_css("[data-phantom-hint]"),
           "the hint needs somewhere to render"
  end

  test "the card leads with the USDC-on-Solana mark, composed from the real assets" do
    html = with_video_id(nil) { render_card }
    doc  = Nokogiri::HTML5.fragment(html)
    mark = doc.at_css("[data-usdc-solana-mark]")

    assert mark, "the card's image must render"
    # COMPOSED, NOT REDRAWN. Both are the shipped brand files; inlining a copy of
    # either path would be a third copy of a brand that is not ours to restyle.
    assert_equal "/usdc-mark.svg",   mark.at_css("[data-mark='usdc']")&.[]("src")
    assert_equal "/solana-mark.svg", mark.at_css("[data-mark='solana']")&.[]("src")
    assert_equal "img", mark["role"], "it is an image, and it needs a name"
    assert_equal "USDC on Solana", mark["aria-label"]
  end

  # --- the optional player ----------------------------------------------------

  test "the teaching band always ships a player, falling back to the wallet walkthrough" do
    html = with_video_id(nil) { render_card }
    doc  = Nokogiri::HTML5.fragment(html)

    frame = doc.at_css("iframe")
    assert frame, "a card that says 'buy USDC in Phantom' and shows nothing is the worse failure"
    assert_includes frame["src"], BuyUsdcHelper::DEFAULT_VIDEO_ID,
                    "the card plays the operator's own USDC video"
    assert_includes frame["src"], "start=58",
                    "started where the video gets to the point"
    assert_includes html, "New to USDC"
    assert doc.at_css("[data-usdc-guide]"), "the read-it-instead route stays"
    assert doc.at_css("button[aria-label='Unmute the video']"),
           "a silent autoplaying player needs the tap-for-sound overlay"
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
end
