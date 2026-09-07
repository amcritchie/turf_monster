# View seam for the Get USDC modal — the teaching half of the funds wall.
#
# Sibling of WalletSetupHelper. That helper answers "how do I get a wallet?";
# this one answers the question immediately after it, "how do I get the money
# that goes in it?". The two modals are deliberately the same shape, so the
# seams are too — same guide resolution, same video query, same nocookie host.
module BuyUsdcHelper
  # Coinbase's own walkthrough — the fallback target, and a real one: it covers
  # the same buy-and-send path the Coinbase rail in Top Up Wallet takes.
  COINBASE_USDC_GUIDE_URL = "https://www.coinbase.com/learn/tips-and-tutorials/how-to-buy-usdc".freeze

  # Resolved at render time, not hard-linked, for the same reason
  # WalletSetupHelper#wallet_setup_guide_url is: /getting-started is the intended
  # house destination and it ships on its own schedule. Ask the ROUTE, so the CTA
  # switches over the moment the page exists and can never ship a dead link.
  def buy_usdc_guide_url
    return getting_started_path if respond_to?(:getting_started_path)

    COINBASE_USDC_GUIDE_URL
  end

  # True when the resolved guide is off-site, so the link opens in a new tab and
  # keeps the player's lineup alive in this one.
  def buy_usdc_guide_external?
    buy_usdc_guide_url.start_with?("http")
  end

  # --- The Phantom rail ----------------------------------------------------
  #
  # Where the row goes. Phantom exposes NO web API for "open your buy screen", so
  # a page cannot send anyone straight there; the honest destination is Phantom's
  # own site.
  #
  # THIS IS A MARKETING LANDING PAGE, NOT A UNIVERSAL LINK, and an earlier version
  # of this comment claimed otherwise while citing modals/_wallet_setup as
  # precedent. Both were wrong: _wallet_setup uses phantom.com/download, and the
  # real universal link is the phantom.app/ul/... form solana-studio's deep-link
  # partial builds. Nothing here opens an installed app — it opens a web page.
  #
  # Overridable so the operator can point it at a specific buy guide without a
  # deploy, the same way BUY_USDC_VIDEO_ID works. The default stays the bare site
  # rather than a guessed deep path: a 404 in a CTA on this card is worse than a
  # general landing page.
  PHANTOM_BUY_URL = "https://phantom.com/".freeze

  def phantom_buy_url
    ENV["PHANTOM_BUY_URL"].presence || PHANTOM_BUY_URL
  end

  # --- The explainer video -------------------------------------------------
  #
  # THE OPERATOR SUPPLIES THIS ONE. WalletSetupHelper pins a third-party video by
  # id because that video was chosen when the modal was built; this modal ships
  # BEFORE its video exists (operator ask, 2026-09-05: "so I can provide a video
  # for how to buy USDC"). So the id is configuration, not a constant to edit:
  # set BUY_USDC_VIDEO_ID and the band grows a player.
  #
  # ABSENT IS A SUPPORTED STATE, not a broken one. With no id configured the
  # teaching band renders its heading and the Detailed Guide CTA and simply has
  # no player — the same discipline onramp_rail_visible? applies to a flagged-off
  # rail. The alternative, an embed with an empty id, renders YouTube's own error
  # card inside the modal, which is worse than the absence it is reporting.
  # Defaults to the Phantom onboarding walkthrough the wallet-setup card already
  # plays (operator, 2026-09-06: "for now just use the same phantom onboarding
  # youtube video"). A card that tells someone to buy USDC inside Phantom and
  # then shows them nothing is the worse failure; a general Phantom walkthrough
  # is imperfect but honest, and it is the SAME video, not a second copy of the
  # id — so the two cannot drift.
  #
  # BUY_USDC_VIDEO_ID overrides it, which is how the purpose-made video lands
  # without a deploy when it exists.
  def buy_usdc_video_id
    ENV["BUY_USDC_VIDEO_ID"].presence || WalletSetupHelper::PHANTOM_INTRO_VIDEO_ID
  end

  # The band's player gate. Views ask this, never the id, so "configured" stays
  # one decision in one place.
  def buy_usdc_video?
    buy_usdc_video_id.present?
  end

  # Same nocookie host as the wallet video, and deliberately the same constant:
  # it is the host named in the CSP frame-src allowlist
  # (config/initializers/content_security_policy.rb). A second host here would
  # render as a blocked blank frame until someone remembered the CSP.
  def buy_usdc_video_embed_url
    return nil unless buy_usdc_video?

    query = {
      "autoplay" => "1",       # start it; motion earns a glance a poster does not
      "mute" => "1",           # ...and this is the only way autoplay is permitted
      "enablejsapi" => "1",    # so the unmute click can reach the player
      "rel" => "0",            # no end-screen grid of unrelated crypto videos
      "modestbranding" => "1",
      "playsinline" => "1"     # iOS: play in the modal, not fullscreen takeover
    }.map { |k, v| "#{k}=#{CGI.escape(v)}" }.join("&")

    "#{WalletSetupHelper::PHANTOM_INTRO_VIDEO_HOST}/embed/#{CGI.escape(buy_usdc_video_id)}?#{query}"
  end

  # The watch-on-YouTube destination, for the accessible link behind the facade.
  def buy_usdc_video_watch_url
    return nil unless buy_usdc_video?

    "https://www.youtube.com/watch?v=#{CGI.escape(buy_usdc_video_id)}"
  end
end
