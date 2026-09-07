require "test_helper"

class LandingPagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @active   = landing_pages(:launch) # active, contest: one
    @inactive = landing_pages(:draft)  # inactive, no contest
    @admin    = users(:alex)
  end

  test "shows an active landing page to anyone" do
    get landing_page_path(@active)
    assert_response :success
    assert_select "h1", text: @active.headline
  end

  test "renders the CTA pointing at the contest" do
    get landing_page_path(@active)
    assert_select "a[href=?][target=_blank]", contest_path(@active.contest.slug, scroll: 280), text: @active.cta_label
  end

  test "visiting seeds the reference cookie with the slug" do
    get landing_page_path(@active)
    assert_equal @active.slug, cookies[:reference]
  end

  test "an existing reference cookie is not overwritten by a landing page" do
    get faucet_path, params: { reference: "campaign-x" }
    get landing_page_path(@active)
    assert_equal "campaign-x", cookies[:reference]
  end

  test "inactive page is hidden from the public" do
    get landing_page_path(@inactive)
    assert_redirected_to root_path
  end

  test "inactive page is visible to admins for preview" do
    log_in_as(@admin)
    get landing_page_path(@inactive)
    assert_response :success
  end

  test "unknown slug redirects" do
    get landing_page_path("does-not-exist")
    assert_redirected_to root_path
  end

  test "a survivor contest funnel shows survivor copy and a free entry" do
    survivor = Contest.create!(name: "WC Survivor Test", game_type: "world_cup_survivor",
                               contest_type: "survivor_wc_free", status: "open")
    lp = LandingPage.create!(name: "Survivor Funnel", headline: "Last One Standing",
                             contest: survivor, active: true)
    get landing_page_path(lp)
    assert_response :success
    assert_select "p", text: "Win or draw to survive"       # survivor how-it-works step
    assert_select "p", text: "Pick 6 teams", count: 0 # not the Turf Totals copy
    assert_select "p", text: "Free"                         # $0 entry renders as Free
  end

  test "renders the gradient background by default" do
    get landing_page_path(@active)
    assert_response :success
    assert_select ".lp-bg"
  end

  test "renders the blob background when the page selects it" do
    @active.update!(background_style: "blobs")
    get landing_page_path(@active)
    assert_response :success
    assert_select ".lp-blobs svg"
    assert_select ".lp-bg", count: 0
  end

  test "renders the circles background when the page selects it" do
    @active.update!(background_style: "circles")
    get landing_page_path(@active)
    assert_response :success
    assert_select ".lp-circles"
    assert_select ".lp-bg", count: 0
  end

  test "renders the badge when set" do
    @active.update!(badge: "Alpha Test")
    get landing_page_path(@active)
    assert_response :success
    assert_select ".lp-badge", text: "Alpha Test"
  end

  test "renders no badge when the badge is blank" do
    get landing_page_path(@active) # launch fixture has no badge
    assert_response :success
    assert_select ".lp-badge", count: 0
  end

  # --- Funnel copy regression: the NFL branch must not speak World Cup. ---
  #
  # `Contest#game_type` is a TWO-value enum (contest.rb:45), so the helper's
  # else branch serves EVERY NFL (turf_totals) contest *and* the no-contest
  # draft preview. Both are asserted below, because a fix that lands on one
  # audience and misses the other is the bug again in a new costume.
  #
  # These read the RENDERED subtree, not the source: a `data-test` scope keeps
  # the layout's own nav/footer/meta copy out of the assertion, which a
  # page-wide assert_select would silently swallow.

  # Copy that would strand the reader in the wrong sport.
  WRONG_SPORT = /world cup|survivor|goals scored/i

  # A hardcoded calendar date rots the day after it passes, and "simulated"
  # is rehearsal vocabulary that must never reach a real-money funnel.
  REHEARSAL_NOISE = /simulated|\b(?:mon|tues|wednes|thurs|fri|satur|sun)day\b|\bthe \d{1,2}(?:st|nd|rd|th)\b|\b\d{1,2}(?::\d{2})?\s*[ap]m\b|\b[MECP][SD]T\b/i

  def funnel_steps_text
    subtree = css_select("[data-test='funnel-how-it-works']")
    assert_equal 1, subtree.size, "expected exactly one funnel how-it-works block"
    subtree.first.text
  end

  test "NFL contest funnel steps name NFL picks, never World Cup" do
    assert @active.contest.turf_totals?, "fixture guard: launch funnel must be an NFL contest"

    get landing_page_path(@active)
    assert_response :success

    steps = funnel_steps_text
    assert_match(/NFL/, steps, "the NFL funnel must name the sport it is selling")
    assert_no_match(WRONG_SPORT, steps, "NFL funnel is showing World Cup copy")
  end

  test "NFL contest funnel steps carry no hardcoded date and no rehearsal wording" do
    get landing_page_path(@active)
    assert_response :success

    assert_no_match(REHEARSAL_NOISE, funnel_steps_text,
                    "public funnel is showing a hardcoded rehearsal date or simulated-games copy")
  end

  test "draft preview with no contest gets the same NFL copy and no rehearsal date" do
    assert_nil @inactive.contest, "fixture guard: draft funnel must have no contest wired"

    log_in_as(@admin) # inactive pages are admin-preview only
    get landing_page_path(@inactive)
    assert_response :success

    steps = funnel_steps_text
    assert_match(/NFL/, steps, "the no-contest draft preview must name the sport too")
    assert_no_match(WRONG_SPORT, steps, "draft preview is showing World Cup copy")
    assert_no_match(REHEARSAL_NOISE, steps, "draft preview is showing a hardcoded rehearsal date")
  end

  test "NFL funnel rulebook link points at the sitewide NFL rules page" do
    get landing_page_path(@active)
    assert_response :success

    # turf-monster-v1 is the NFL rulebook and the canonical target in the
    # navbar, footer and transparency hub; turf-totals-v1 is the PREVIOUS
    # season's page and still badged "World Cup 2026" (routes.rb:81-87).
    assert_select "[data-test='funnel-footer'] a[href=?]", turf_monster_v1_path
    assert_select "[data-test='funnel-footer'] a[href=?]", turf_totals_v1_path, count: 0
  end

  test "survivor funnel keeps its own copy and gains no NFL wording" do
    survivor = Contest.create!(name: "WC Survivor Copy", game_type: "world_cup_survivor",
                               contest_type: "survivor_wc_free", status: "open")
    lp = LandingPage.create!(name: "Survivor Copy Funnel", headline: "Last One Standing",
                             contest: survivor, active: true)

    get landing_page_path(lp)
    assert_response :success

    steps = funnel_steps_text
    assert_match(/survive/i, steps, "survivor funnel must keep its survivor copy")
    assert_no_match(/NFL/, steps, "NFL copy leaked into the survivor branch")
  end
end
