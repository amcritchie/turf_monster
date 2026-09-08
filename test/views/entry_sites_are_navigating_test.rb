# frozen_string_literal: true

require "test_helper"

# EVERY onchainSettled() CALL ON A SURFACE THAT REDIRECTS MUST PASS navigating.
#
# This is a source invariant, and it is deliberately narrow about what it proves:
# it cannot show the settle working, only that no call site has quietly gone back
# to the form that cannot survive a redirect. The behaviour itself is covered by
# the component tests and e2e/onchain_settled_navbar.spec.js.
#
# WHY IT EXISTS. This PR shipped on the premise that "the entry flow does not
# navigate". It was false and nothing caught it: the engine's success card
# auto-redirects after FIVE seconds (studio/modals/blocks/_success_card:70,
# armed by _entry_confirmed:92, ending in window.location.href), so a ten-second
# non-navigating timer is destroyed at t=5s with no marker written — the exact
# silent no-op the marker machinery exists to prevent, on the flagship path.
#
# The failure mode is invisible: a bare call is valid JavaScript, does something
# plausible, and leaves no trace when the page unloads. So the invariant is
# asserted rather than remembered.
class EntrySitesAreNavigatingTest < ActiveSupport::TestCase
  # Surfaces whose success card redirects on its own countdown.
  REDIRECTING_SURFACES = %w[
    app/views/contests/_turf_totals_board.html.erb
    app/views/contests/_world_cup_survivor_board.html.erb
    app/views/contests/new.html.erb
    app/views/contests/generator.html.erb
  ].freeze

  test "no redirecting surface calls onchainSettled without navigating" do
    offenders = REDIRECTING_SURFACES.flat_map do |rel|
      path = Rails.root.join(rel)
      assert path.exist?, "#{rel} moved — update this list rather than deleting the guard"

      path.read.each_line.with_index(1).filter_map do |line, n|
        next unless line.include?("onchainSettled(")
        next if line.include?("navigating: true")
        next if line.strip.start_with?("//")   # prose about the call, not the call
        "#{rel}:#{n} — #{line.strip}"
      end
    end

    assert_empty offenders,
      "these sites redirect, so a bare onchainSettled() schedules a timer the unload destroys:\n" +
      offenders.join("\n")
  end

  # THE CONTROL. Without it the test above passes trivially if the calls are all
  # renamed or deleted — it would be asserting the absence of something absent.
  test "the redirecting surfaces do in fact call onchainSettled" do
    counts = REDIRECTING_SURFACES.to_h do |rel|
      [rel, Rails.root.join(rel).read.scan(/onchainSettled\(\{ navigating: true \}\)/).length]
    end

    counts.each do |rel, n|
      assert_operator n, :>=, 1,
        "#{rel} has no navigating onchainSettled call — either the seam was removed or this " \
        "list is stale, and both make the test above vacuous"
    end
    assert_equal 8, counts.values.sum,
      "expected 8 navigating call sites (4 board + 2 survivor + create + generator); " \
      "a change in this number means a success path was added or lost"
  end
end
