# Every email Turf Monster sends, registered on the shared engine catalog
# (Studio::EmailCatalog, studio-engine >= 0.35).
#
# This file replaces app/models/email_catalog.rb and the whole
# Admin::EmailsController + app/views/admin/emails stack, which are deleted.
# Those carried the note "moves into the shared studio-engine email framework
# (Phase 2)" from the day they were written; this is that move. The engine page
# at /admin/emails is a strict superset of the one being retired — same name,
# description, type and live preview, plus the banner image, whether that banner
# is inherited or this app's own, upload through the shared crop modal, and
# revert.
#
# `default_asset` resolves through THIS APP's asset pipeline, so these point at
# turf-monster's own committed artwork in app/assets/images/emails. An operator
# uploading a replacement on /admin/emails writes to turf-monster's S3 bucket and
# its own image_caches row, which then wins over the file named here — the file
# is the floor, not the ceiling.
#
# to_prepare, not a bare initializer: Studio::EmailCatalog is autoloaded, so
# registrations made once at boot are lost on the first dev reload.
Rails.application.config.to_prepare do
  # Sample data for the previews. Deliberately tolerant — a preview builder runs
  # against whatever this environment happens to hold, and the engine contains a
  # failure to one preview rather than the page, but returning a usable stand-in
  # keeps the manager useful on a thin database.
  sample_user = lambda do
    User.where.not(email: nil).first || User.new(email: "you@example.com", username: "turf-fan")
  end
  sample_token = "preview-token-not-real"

  Studio::EmailCatalog.register(
    "magic_link",
    label: "Magic-link sign-in",
    description: "Passwordless create-or-login link.",
    type: :transactional,
    default_asset: "emails/magic-link-banner.jpg",
    # The layered background this entry used to carry,
    # "emails/magic-link-background.gif", is still committed in this repo — a
    # copy of the shared studio artwork, kept here deliberately rather than
    # resolved from the gem so restoring the layered banner stays a one-file
    # change and never silently inherits studio-engine's picture of the same
    # name. It is simply not registered any more; see below.
    #
    # FLAT, deliberately — Mr. McRitchie asked for the July artwork back
    # (2026-09-07). magic-link-banner.jpg is a FINISHED banner: "Your Magic Link"
    # and "Click the link below to log in." are baked into the picture, which is
    # why the body template calls itself "deliberately minimal". Drawing the
    # layered header over it would print the words twice.
    #
    # ONE key does it, and it has to be "" rather than deleted. `register` merges
    # on `.presence`: nil INHERITS and "" CLEARS, so dropping this line puts the
    # engine's island back — the silent inheritance the note above warns about.
    #
    # A cleared background is the DOCUMENTED way to send an entry flat, not a
    # trick: Studio::Banner.for ends `banner.background_url.present? ? banner :
    # nil` over the comment "a nil background means the catalogue said this app
    # sends the email flat". So Banner.for returns nil, branded_mailer falls past
    # `@banner.renderable?` to the `@banner_url` <img>, and that is
    # resolved_url(:magic_link) — this file's default_asset, the July jpg.
    # @banner_alt already falls back to "Your Magic Link" when @banner is nil.
    #
    # Do NOT also blank header/subtext to "make sure". Banner.for never reaches
    # renderable? once the background is nil, so they change nothing today — and
    # clearing them would throw away the wording ("Welcome {name}!") that
    # restoring this one line is supposed to bring back with it.
    #
    # THE TRADE: this email's header and sub-text stop being editable on
    # /admin/emails, because the wording now lives in the artwork. They are
    # still REGISTERED and still inherited, so restoring the layered banner is
    # putting a real background back on this one key.
    background: "",
    # THIS APP'S OWN MARK, and it must stay a path this app OWNS. The value here
    # was "emails/logo-horizontal.png" — a file turf does not have. Sprockets
    # served studio-engine's copy of that name, so the sign-in email went out
    # carrying the McRITCHIE STUDIO wordmark under an alt of "Turf Monster".
    # Nothing raised; the guard in test/mailers/user_mailer_test.rb now asserts
    # the file exists HERE rather than that the URL merely contains the name.
    #
    # PLACEHOLDER, by Mr. McRitchie's call — the green monster mark from
    # public/icon-512.png, resized to 360px so it is retina-sharp at the 180px
    # the banner draws it. It is square where the engine's is horizontal, so it
    # sits taller in the banner than a wordmark would. Replace it with a proper
    # horizontal Turf Monster wordmark when one exists.
    #
    # If you ever want NO logo, set "" — deleting the line puts the engine's
    # wordmark BACK, because register merges on `logo.presence`: "" clears, while
    # nil and an omitted key both inherit the STANDARD seed. An operator can also
    # clear it with no deploy via hide_logo? on /admin/emails.
    logo: "emails/turf-logo.png",
    preview: -> { UserMailer.magic_link(sample_user.call.email, sample_token) }
  )

  Studio::EmailCatalog.register(
    "email_verification",
    label: "Email verification",
    description: "Verify the email address on an account.",
    type: :transactional,
    default_asset: "emails/verify-banner.jpg",
    preview: -> { UserMailer.email_verification(sample_user.call, sample_token) }
  )

  Studio::EmailCatalog.register(
    "wallet_export",
    label: "Wallet export",
    description: "Self-custody wallet export reveal link.",
    type: :transactional,
    default_asset: "emails/wallet-export-banner.jpg",
    preview: -> { UserMailer.wallet_export(sample_user.call, sample_token) }
  )

  Studio::EmailCatalog.register(
    "email_change_notification",
    label: "Email change — notify old address",
    description: "Heads-up to the OLD address when an email change is requested.",
    type: :transactional,
    default_asset: "emails/email-change-notify-banner.jpg",
    preview: -> { UserMailer.email_change_notification(sample_user.call, "old@example.com", "new@example.com") }
  )

  Studio::EmailCatalog.register(
    "email_change_confirmation",
    label: "Email change — confirm new address",
    description: "Confirm link sent to the NEW address for an email change.",
    type: :transactional,
    default_asset: "emails/email-change-confirm-banner.jpg",
    preview: lambda {
      user = sample_user.call
      UserMailer.email_change_confirmation(user, user.email, "new@example.com", sample_token)
    }
  )

  Studio::EmailCatalog.register(
    "friend_joined_contest",
    label: "Friend joined contest",
    description: "Referral notification when an invitee joins a contest.",
    type: :transactional,
    default_asset: "emails/friend-joined-banner.jpg",
    preview: lambda {
      inviter = User.where.not(email: nil).first
      invitee = User.where.not(email: nil).where.not(id: inviter&.id).first || sample_user.call
      invitee.inviter = inviter # in-memory, preview only
      InviterMailer.friend_joined_contest(invitee: invitee)
    }
  )

  Studio::EmailCatalog.register(
    "contest_winnings",
    label: "Contest winnings",
    description: "Payout notification when a user wins a contest.",
    type: :transactional,
    default_asset: "emails/winnings-banner.jpg",
    preview: lambda {
      entry = ::Entry.where("payout_cents > 0").where.not(rank: nil).first ||
              ::Entry.where.not(rank: nil).first ||
              ::Entry.first
      ContestMailer.winnings(entry)
    }
  )

  Studio::EmailCatalog.register(
    "newsletter_welcome",
    label: "Newsletter welcome",
    description: "Sent from Alex on a user's first newsletter subscribe (the 25-seed quest).",
    type: :marketing,
    default_asset: "emails/welcome-banner.jpg",
    preview: -> { NewsletterMailer.welcome(sample_user.call) }
  )
end
