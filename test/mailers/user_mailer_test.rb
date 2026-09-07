require "test_helper"

# The sign-in email's FLAT banner — a finished picture, sent as an <img>.
#
# This file used to pin the opposite. The email was layered from 2026-08-13
# (task turf-owns-its-banner-artwork): engine island artwork with a live HTML
# greeting drawn over it. Mr. McRitchie asked for July's artwork back on
# 2026-09-07 — the green wizard gator, whose words are part of the picture — so
# the greeting had nowhere to go and the layering was retired for THIS entry.
# The guards below are rebound rather than deleted: each one still asks the
# question it was written to ask, of the shape the email now has.
#
# turf-monster defines its own UserMailer, so nothing in the engine's suite can
# speak for this app: the engine's tests exercise the engine's mailer, which is
# never loaded here. The division of labour these guards protect is that the
# MAILER supplies who the recipient is and /admin/emails supplies what the
# banner says about them — a mailer that hands over a finished header takes the
# wording away from the operator, whose fields then accept edits no inbox sees.
class UserMailerTest < ActionMailer::TestCase
  def render(email)
    message = UserMailer.magic_link(email, "token-for-test-1234")
    [(message.html_part&.body || message.body).to_s, message]
  end

  def banner_header(html) = html[/font-weight:700;color:#ffffff;">\s*([^<]+)/, 1]&.strip

  # --- it layers at all -----------------------------------------------------

  # THE INVERSE OF THE ASSERTION THAT USED TO LIVE HERE, and the reason the rest
  # of this file moved. It holds on ONE registry key: a cleared `background`.
  # Studio::Banner.for ends `banner.background_url.present? ? banner : nil`, so a
  # nil background is the catalogue saying this app sends the email flat, and
  # branded_mailer then falls past @banner to the @banner_url <img>.
  #
  # "" and not deleted: `register` merges on `.presence`, so nil INHERITS the
  # engine's island and only "" clears it. Blanking header/subtext as well
  # changes nothing — Banner.for never reaches renderable? once the background
  # is gone — and it would discard the wording a future re-layering wants back.
  test "the banner is the flat image, not a layered one" do
    html, = render(users(:alex).email)

    assert_includes html, "magic-link-banner",
      "the July artwork ships as an <img>; this is the file the inbox shows"
    refute_includes html, "background-size:cover",
      "a layered banner would draw artwork as a CSS background — this entry is flat"
    refute_includes html, "v:rect",
      "the VML block belongs to the layered banner and has nothing to draw here"
  end

  # INHERITED ON PURPOSE — "island now, gator later" (Mr. McRitchie, 2026-08-13).
  #
  # The guard here asserted that THIS APP owns the registered file
  # (Rails.root.join("app/assets/images", entry.background).exist?) and it was
  # RED, correctly: turf owns no layered artwork, so the sign-in email draws
  # studio-engine's shared violet island. That is now the decision rather than
  # the defect — turf's own background is deferred to
  # https://mcritchie.studio/tasks/turf-owns-its-banner-artwork.
  #
  # What this does NOT go back to is the substring check that ownership
  # assertion replaced ("does the resolved URL contain magic-link-background").
  # That passed whether the file came from this app or from the gem, so it was
  # blind to the one thing the decision is about — and it is the guard that let
  # the engine's wordmark ship beside it unnoticed. This one is not blind: it
  # names the engine as the source and goes red if that stops being true.
  #
  # Two properties, deliberately different in kind:
  #
  #   1. IT RESOLVES. The one an inbox feels. EmailCatalog#asset_path rescues
  #      StandardError to nil, and _layered_banner.html.erb gates every
  #      background path — the td attribute, the CSS, the whole VML block — on
  #      background_url.present?. So an upstream rename or removal raises
  #      NOTHING: the email quietly ships a flat theme-colour box with the
  #      greeting on it. Asking the pipeline unrescued is what turns that
  #      silence into a red test.
  #   2. IT IS THE ENGINE'S, AND THAT IS A CHOICE. Asserted positively against
  #      the gem's own asset tree, so "inherited" is something the suite checks
  #      rather than a comment someone has to take on faith.
  #
  # WHEN THE GATOR LANDS: committing app/assets/images/emails/
  # magic-link-background.gif fires the last assertion below, by design.
  # Replace the two provenance assertions with the ownership one this task
  # relaxed —
  #   assert Rails.root.join("app/assets/images", entry.background).exist?
  # — and delete this paragraph. The resolution assertion stays either way.
  # OWNERSHIP, flipped as the tripwire that used to live here instructed. This
  # asserted the file was still studio-engine's and REFUTED that turf owned it,
  # because turf deliberately inherited the island loop. Turf now commits its own
  # copy — Mr. McRitchie's call, keeping the Studio artwork for now and swapping
  # in turf's later — so the provenance flipped and the assertion flips with it.
  #
  # A copy rather than a re-registered gem path, because owning the file is what
  # makes "swap it later" a one-file change, and it is what stops the silent
  # inheritance this entry had before: the same NAME resolved from studio-engine
  # and nothing on the page or in the email could tell you which one shipped.
  # The same two properties this asked of the background, asked of the picture
  # that now ships. Both still matter, and the first matters MORE flat than
  # layered: EmailCatalog#asset_path rescues StandardError to nil, so a rename or
  # a removal upstream raises nothing and the email goes out with a broken <img>
  # where its entire content used to be. Asking the pipeline unrescued is what
  # turns that silence into a red test.
  test "this app owns the flat artwork it sends" do
    entry = Studio::EmailCatalog.entry("magic_link")

    refute entry.background.present?,
      "a registered background puts the layered banner back and the artwork's " \
      "own words would be printed over twice"

    resolved =
      begin
        ActionController::Base.helpers.asset_path(entry.default_asset)
      rescue StandardError
        nil # Sprockets raises AssetNotFound here; the message below says the cost
      end
    assert resolved.present?,
      "#{entry.default_asset} is registered but does not resolve in this app's " \
      "asset pipeline. Nothing raises in production — the sign-in email would " \
      "ship a broken image where its whole banner belongs."

    assert Rails.root.join("app/assets/images", entry.default_asset).exist?,
      "#{entry.default_asset} is registered but this app does not own it — it is " \
      "resolving from studio-engine, so the sign-in email ships the ENGINE's " \
      "artwork. Add the file to app/assets/images or register the app's own."
  end

  # THE SAME GUARD FOR THE LOGO, because the logo is where the leak actually
  # shipped: this entry registered "emails/logo-horizontal.png", turf has no such
  # file, and Sprockets served studio-engine's — so the sign-in email carried the
  # McRITCHIE STUDIO wordmark. The alt text said "Turf Monster" the whole time,
  # which is what made it invisible. A URL-substring assertion cannot see this;
  # only the file on disk separates ours from the gem's.
  # Still registered and still owned, but DORMANT for this entry: the logo is
  # drawn by the layered partial, which no longer runs here. Kept asserting
  # anyway, because the registration is what a future re-layering would pick up,
  # and a file that quietly stopped existing in between is exactly how the
  # engine's wordmark shipped the first time.
  test "this app's own logo is what ships" do
    entry = Studio::EmailCatalog.entry("magic_link")
    skip "this entry ships no logo" if entry.logo.blank?

    path = Rails.root.join("app/assets/images", entry.logo)
    assert path.exist?,
      "#{entry.logo} is registered but this app does not own it — it is resolving " \
      "from studio-engine, so the sign-in email ships the ENGINE's mark."
  end

  # The wordmark by name, so a re-introduction is caught however it gets there —
  # a reverted line, a merge, or an operator upload that happens to be named for
  # the engine's asset.
  test "the engine's wordmark does not ride along" do
    html, = render(users(:alex).email)

    refute_includes html, "logo-horizontal",
      "that asset is studio-engine's McRitchie Studio wordmark"
  end

  # --- who it greets: nobody, now -------------------------------------------
  #
  # THIS SECTION USED TO PIN THE OPPOSITE, and the loss is deliberate rather
  # than incidental. The layered banner greeted a recipient by handle ("Welcome
  # alex!") and fell back to a name-free header for a stranger, which is a live
  # path — a magic link is often the FIRST thing someone receives, with no
  # account and no name. July's artwork says "Your Magic Link" to everyone
  # because the words are in the picture, so personalisation had nowhere to go.
  # Recorded here so the trade is visible to whoever reads this next, and so
  # re-layering restores these three assertions along with the header.
  #
  # What SURVIVES the change is the property that had teeth: the banner must
  # never show a recipient a fragment of their own email address. display_name
  # falls back to the address's local part, so the layered header was one
  # careless call away from printing it. Flat, that cannot happen — and this
  # asserts it rather than assuming it, because "cannot happen" is what the
  # earlier version of this email believed too.

  test "the banner greets nobody and is identical for every recipient" do
    known, = render(users(:alex).email)
    stranger, = render("nobody-here@example.test")

    assert_nil banner_header(known), "a flat banner draws no live header"
    assert_nil banner_header(stranger)
    refute_includes known, "Welcome", "the greeting belongs to the layered banner"
  end

  test "the banner never shows a recipient their own address" do
    user = users(:alex)
    user.update_columns(username: nil, name: nil)

    html, = render(user.email)
    local_part = user.email.split("@").first

    # Scoped to the banner, not the document: the body legitimately prints the
    # full address ("This link is for alex@…"), so a whole-page refutation would
    # fail on correct output. The banner is the <img> and its alt text.
    banner = html[/<img[^>]*magic-link-banner[^>]*>/].to_s
    assert banner.present?, "the flat banner should render as an <img>"
    refute_includes banner, local_part
    assert_includes banner, "Your Magic Link", "the alt text still names the email"
  end

  # --- it is still a sign-in email ------------------------------------------

  test "the token still reaches the recipient" do
    html, message = render(users(:alex).email)

    assert_includes html, "token-for-test-1234", "the link is the point of the email"
    assert_equal [users(:alex).email], message.to
  end

  test "the other emails are untouched by this change" do
    message = UserMailer.email_verification(users(:alex), "token-for-test-1234")
    html = (message.html_part&.body || message.body).to_s

    refute_includes html, "background-size:cover",
      "only magic_link registered layered artwork; the rest still send their flat banners"
  end
end
