require "test_helper"

# The World Cup rulebook (turf-totals-v1) published a "Per-Game Lock" section
# promising that "each selection locks when its specific game kicks off — not
# all at once" and that a player "can change or swap picks for games that
# haven't started yet, even after confirming your entry".
#
# Entry refuses all of it. The H7 prelaunch audit (2026-05-24, entry.rb's
# assert_enterable! comment) closed exactly that behaviour as the
# staggered-kickoff information-edge attack: wait past the contest's stated
# lock, read live scores from games that already kicked off, then submit picks
# drawn from later-kickoff matchups whose own `locked?` is still false. The
# page documented the exploit as a feature for roughly three and a half months,
# on a real-money page every funnel visitor lands on.
#
# So this guard does NOT grep for a replacement sentence — that rots at the
# next reword. It MEASURES what Entry enforces against a staggered slate, then
# requires the published copy to agree with the measurement. If someone ever
# reintroduces per-game locking in the model, the measurement flips and this
# test demands the page be changed back. If someone rewrites the page toward
# the old promise, the copy assertions fail against the unchanged code.
class TurfTotalsLockRuleTest < ActionDispatch::IntegrationTest
  # A slate with two kickoff waves is the exact shape the old copy described:
  # an early game that sets the contest lock, and a later game whose own
  # `SlateMatchup#locked?` is still false once that lock has passed.
  setup do
    @early_kickoff = 3.days.from_now.change(min: 0, sec: 0, usec: 0)
    @late_kickoff = @early_kickoff + 6.hours

    @slate = Slate.create!(name: "Lock Rule Slate", slug: "lock-rule-slate",
                           sport: "fifa", starts_at: @early_kickoff)

    early_game = Game.create!(slug: "lock-rule-early", home_team_slug: "team-a",
                              away_team_slug: "team-b", kickoff_at: @early_kickoff,
                              status: "scheduled")
    late_game = Game.create!(slug: "lock-rule-late", home_team_slug: "team-c",
                             away_team_slug: "team-d", kickoff_at: @late_kickoff,
                             status: "scheduled")

    # The waves hold DISJOINT teams: Selection#name_slug is "<entry>-<team>", so
    # one entry may never hold the same team twice. Two extra teams give the
    # late wave spare matchups to swap IN, which is the move the old copy
    # promised was still available after the contest lock.
    spare_teams = ["Lock Rule Team G", "Lock Rule Team H"].map { |n| Team.create!(name: n).slug }

    rank = 0
    build_wave = lambda do |game, team_slugs|
      team_slugs.each_slice(2).flat_map do |a, b|
        [[a, b], [b, a]].compact.filter_map do |team, opponent|
          next if team.nil?

          SlateMatchup.create!(slate: @slate, team_slug: team, opponent_team_slug: opponent,
                               game_slug: game.slug, rank: (rank += 1),
                               turf_score: 1.0, status: "pending")
        end
      end
    end

    @early_matchups = build_wave.call(early_game, %w[team-a team-b team-c])
    @late_matchups = build_wave.call(late_game, %w[team-d team-e team-f] + spare_teams)

    # starts_at is left blank on purpose: Contest#locks_at then DERIVES the lock
    # from the slate's first kickoff, which is the production derivation and the
    # rule the page publishes ("the first kickoff on its slate").
    @contest = Contest.create!(name: "Lock Rule Contest", slug: "lock-rule-contest",
                               entry_fee_cents: 1900, status: "open", max_entries: 29,
                               contest_type: "standard", slate: @slate, starts_at: nil)

    @entry = Entry.create!(user: users(:alex), contest: @contest, status: "cart")
    @picked = @early_matchups + @late_matchups.first(@contest.picks_required - @early_matchups.size)
    @picked.each { |m| @entry.selections.create!(slate_matchup: m) }
    @spare_late = @late_matchups - @picked
  end

  # ── the measurement ───────────────────────────────────────────────────────
  # Does the code leave ANY pick editable after the contest lock passes, on the
  # strength of its own game not having kicked off yet? That is the entire
  # claim the old rulebook section made.
  def matchups_still_editable_after_contest_lock
    @late_matchups.select do |matchup|
      refute matchup.locked?, "test setup: #{matchup.team_slug}'s later game must not have kicked off"
      accepted?(matchup)
    end
  end

  def accepted?(matchup)
    Entry.transaction do
      @entry.toggle_selection!(matchup)
      raise ActiveRecord::Rollback
    end
    true
  rescue StandardError
    false
  end

  def rules_subtree_text
    node = css_select('[data-test="turf-totals-rules"]').first
    assert node, "the World Cup rulebook must render its own subtree to scope against"
    node.text
  end

  def scoped_text(hook)
    node = css_select(%([data-test="#{hook}"])).first
    assert node, "the rulebook must render a #{hook} subtree"
    node.text
  end

  test "the World Cup rulebook's lock rule matches the lock Entry enforces" do
    # CONTROL. Without this the measurement below could read "nothing is
    # editable" from a broken setup and certify any copy at all. Before the
    # lock, a spare late-wave pick IS editable — so `accepted?` can answer true,
    # and a false answer after the lock is the lock talking.
    travel_to @contest.locks_at - 1.hour do
      assert accepted?(@spare_late.first),
             "control: a spare pick must be editable BEFORE the contest locks"
    end

    editable = nil
    travel_to @contest.locks_at + 1.minute do
      assert_equal @early_kickoff, @contest.locks_at,
                   "the contest lock must derive from the slate's first kickoff"
      editable = matchups_still_editable_after_contest_lock
    end

    get turf_totals_v1_path
    assert_response :success
    lock_text = scoped_text("lock-rules")

    if editable.any?
      # Per-game locking would be real: the page MUST then say so, and this
      # branch is the one that catches a page left stale after such a change.
      assert_match(/not all at once/i, lock_text,
                   "Entry left #{editable.size} pick(s) editable after the contest lock — " \
                   "the rulebook must document per-game locking")
    else
      # Measured reality: ONE contest-level lock, no per-game exemption.
      assert_match(/locks/i, lock_text, "the lock section must state when a contest locks")
      assert_match(/first kickoff/i, lock_text,
                   "the lock moment the code derives is the slate's first kickoff")
      assert_match(/final/i, lock_text, "the section must say picks are final after the lock")

      # No wording anywhere in the rulebook may promise the swap window the
      # measurement just proved impossible — prose, worked example, or the
      # quick-reference row a reader skims instead of reading.
      page_text = rules_subtree_text
      {
        /not all at once/i => "denies the contest-wide lock",
        /each selection locks when/i => "promises per-selection locking",
        /haven'?t started yet/i => "promises a post-lock swap window",
        /still swap/i => "promises a post-lock swap",
        /even after confirming/i => "promises edits after entry confirmation",
        /per-game kickoff/i => "names a per-game lock moment"
      }.each do |pattern, why|
        refute_match(pattern, page_text,
                     "rulebook copy matching #{pattern.inspect} #{why}, but Entry raises " \
                     "\"Contest has locked — entries closed\" for every pick once " \
                     "Contest#locks_at passes")
      end
    end
  end

  # The worked example is the half of the section a player actually reads, and
  # it carried the promise in concrete numbers. Pinned separately so a fix to
  # the prose alone cannot leave it stale.
  test "the worked example resolves the staggered-kickoff case against the code" do
    get turf_totals_v1_path
    assert_response :success
    example = scoped_text("lock-example")

    assert_match(/final/i, example,
                 "the example must land on picks being final at the contest lock")
    refute_match(/still swap|haven'?t started yet|until 9pm/i, example,
                 "the example must not resolve the later kickoff as extra editing time")
  end

  # The quick-reference table is where a reader skims for THE RULES. It read
  # "Per-game kickoff" — the same false promise in two words.
  test "the quick-reference lock row names the contest lock, not a per-game one" do
    get turf_totals_v1_path
    assert_response :success
    row = scoped_text("lock-quick-ref")

    assert_match(/first kickoff/i, row, "the quick-reference lock row must name the contest lock")
    refute_match(/per-game/i, row, "the quick-reference row must not promise per-game locking")
  end

  # Locks the citation trail the funnel helper hands the next reader: it cites
  # the guards that actually enforce the sentence it prints.
  test "the funnel lock step cites guards that exist and are contest-wide" do
    helper_source = Rails.root.join("app/helpers/landing_pages_helper.rb").read
    entry_source = Rails.root.join("app/models/entry.rb").read

    refute_match(/#submit!/, helper_source,
                 "Entry#submit! does not exist; the citation misroutes the next reader")
    assert_no_match(/def submit!/, entry_source, "guard: Entry#submit! really is absent")

    helper_source.scan(/entry\.rb:([\d,\s:]+)/).flatten.each do |group|
      group.scan(/\d+/).each do |lineno|
        line = entry_source.lines[lineno.to_i - 1].to_s
        assert_match(/contest\.locks_at/, line,
                     "landing_pages_helper cites entry.rb:#{lineno}, which is " \
                     "#{line.strip.inspect} — not the contest-wide lock guard the " \
                     "sentence relies on")
      end
    end
  end
end
