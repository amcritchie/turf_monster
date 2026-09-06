require "test_helper"

# [component] The navbar after the brand rename and the link move.
#
# TWO THINGS THIS DEFENDS, and neither is visual.
#
# 1. THE RENAME IS BRAND-ONLY. "Turf Totals" names two different things in this
#    app: the product, and one of the two GAME MODES (turf_totals vs survivor).
#    A blanket rename reads as a tidy-up and quietly renames the mode — so pin
#    that the wordmark moved and the mode's own rules page did not.
# 2. THE MOVED LINKS ARE STILL REACHABLE. NFL Totals and Reserves left the bar
#    for the gear sidebar, and that sidebar is `return unless current_user`. A
#    logged-out visitor would lose NFL Totals entirely if the footer did not
#    carry it — which is a page vanishing from the site, not a layout tweak.
class NavbarBrandTest < ActionView::TestCase
  NAVBAR = Rails.root.join("app/views/layouts/_navbar.html.erb")
  FOOTER = Rails.root.join("app/views/shared/_footer.html.erb")
  SIDEBAR = Rails.root.join("app/views/components/_gear_sidebar.html.erb")
  RULES_PAGE = Rails.root.join("app/views/pages/turf_totals_v1.html.erb")
  # The one page whose "Turf Totals" is the GAME MODE, not the brand.
  GAME_MODE_PAGE = RULES_PAGE

  # --- the wordmark -----------------------------------------------------------

  test "the wordmark reads Turf Monster" do
    src = NAVBAR.read

    assert_includes src, ">Monster</span>", "the wordmark's second half must read Monster"
    refute_includes src, ">Totals</span>", "no half of the wordmark may still say Totals"
    assert_includes src, 'alt="Turf Monster"', "the logo's alt text is brand copy too"
  end

  test "the game mode keeps its name" do
    # turf_totals is a game_type in the database and the name of the mode the
    # Rules link documents. The rename must not have reached it.
    assert_includes RULES_PAGE.read, "Turf Totals v1",
                    "the mode's own rules page is not brand copy and stays"
    assert_includes NAVBAR.read, "turf_totals_v1_path",
                    "the route identifier is not copy and never renames"
  end

  # THE TEST THAT WOULD HAVE CAUGHT THE MISS. The brand is drawn as TWO SPANS in
  # four places ("Turf" + "Totals"), so a search-and-replace over the string
  # "Turf Totals" sails straight past every one of them — the navbar was renamed
  # while the footer, the landing page and the auth card still read TurfTotals,
  # and only a screenshot found it. Sweep the views instead of trusting the pass.
  # THE SWEEP THAT MISSED THE MANIFEST. The first version of this globbed
  # app/views/**/*.erb, so no file outside app/views could ever fail it — and
  # public/site.webmanifest shipped "Turf Totals" as the PWA name and short_name,
  # which is what a phone puts on the home screen after Add to Home Screen. Sweep
  # every SHIPPING surface the brand can appear on, not just the one the last
  # miss happened to be in.
  BRAND_SURFACES = %w[
    app/views/**/*.erb
    app/helpers/**/*.rb
    app/mailers/**/*.rb
    config/initializers/studio.rb
    public/*.webmanifest
  ].freeze

  # Files whose "Turf Totals" is the GAME MODE (turf_totals vs survivor), not the
  # brand. Every entry needs a reason, because an allowlist is how a real miss
  # gets waved through.
  GAME_MODE_FILES = {
    "app/views/pages/turf_totals_v1.html.erb" => "the mode's own versioned rules page",
    "app/views/pages/terms.html.erb"          => "scopes the editing rule to the mode; Survivor is excluded in the same sentence",
    "app/helpers/landing_pages_helper.rb"     => "comments the else-branch that reads TURF_TOTALS_DEFAULT_PICKS_REQUIRED",
    "app/views/contests/show.html.erb"        => "section comments naming the mode's board",
    "app/views/contests/_world_cup_survivor_board.html.erb" => "a comment contrasting this board with the turf_totals flow"
  }.freeze

  test "no shipping surface still carries the retired brand" do
    offenders = BRAND_SURFACES.flat_map { |g| Dir[Rails.root.join(g)] }
      .map { |f| Pathname(f).relative_path_from(Rails.root).to_s }
      .reject { |rel| GAME_MODE_FILES.key?(rel) }
      .select { |rel| Rails.root.join(rel).read.include?("Turf Totals") }

    assert_empty offenders,
                 "these ship the retired brand: #{offenders.join(', ')} — rename them, " \
                 "or add them to GAME_MODE_FILES WITH a reason if the string is the game mode"
  end

  test "no split wordmark still reads Totals" do
    offenders = Dir[Rails.root.join("app/views/**/*.erb")].reject { |f| f == GAME_MODE_PAGE.to_s }
      .select { |f| File.read(f).match?(/Turf<\/span>\s*<span[^>]*>Totals|Turf <span[^>]*>Totals/) }
      .map { |f| Pathname(f).relative_path_from(Rails.root).to_s }

    assert_empty offenders,
                 "these draw the brand as two spans and still say Totals: #{offenders.join(', ')}"
  end

  # --- the move ---------------------------------------------------------------

  test "NFL Totals and Reserves left the navbar" do
    src = NAVBAR.read

    refute_includes src, '"NFL Totals"', "NFL Totals moved to the gear sidebar"
    refute_includes src, '"Reserves"', "Reserves moved to the gear sidebar"
    # The two that earned their slot are still there.
    assert_includes src, '"Contests"'
    assert_includes src, '"Rules"'
  end

  test "the gear sidebar picked both of them up" do
    src = SIDEBAR.read

    assert_includes src, "nfl_team_totals_path", "NFL Totals must land in the sidebar"
    assert_includes src, "proof_of_reserves_path", "Reserves was already here"
  end

  test "a logged-out visitor can still reach both pages" do
    # The gear sidebar opens with `return unless current_user`, so it is not a
    # destination for anonymous traffic. The footer is, and both pages are public.
    footer = FOOTER.read

    assert_includes SIDEBAR.read, "return unless current_user",
                    "if the sidebar ever became public this test's premise changes"
    assert_includes footer, "nfl_team_totals_path",
                    "NFL Totals would be unreachable logged-out without this"
    assert_includes footer, "proof_of_reserves_path",
                    "Proof of Reserves is a trust page and must stay public-reachable"
  end
end
