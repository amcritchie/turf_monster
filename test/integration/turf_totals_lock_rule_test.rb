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
#
# SCOPE, since the filename undersells it: this file measures Contest and Entry,
# which never branch on sport, then holds EVERY published lock surface to that
# one measurement — the World Cup rulebook, the NFL rulebook, the Terms editing
# clause, and the funnel helper's citation trail. Add a lock surface, add it
# here; do not stand up a second fixture, or the surfaces gain a way to disagree
# with each other about the same code.
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

  # ── the lock WINDOW, measured off the production slate definition ─────────
  # "every pick is final, including picks whose own match kicks off later in
  # the day" was not false — the categorical clauses beside it carry the rule —
  # but it understated the window. A slate is ONE STAGE (seed_slates! groups
  # FIXTURES by stage and sets starts_at to that stage's MIN kickoff), and the
  # Round of 32 spans over five days. A player whose match is three days out
  # can read "later in the day" and infer the window does not reach them.
  #
  # Measured, not asserted: the span comes from the seed the production slates
  # are built from, so if the calendar ever compresses to a single day this
  # guard stops demanding the wider wording.
  def widest_seeded_slate_span
    WorldCup2026KnockoutSeed::FIXTURES
      .group_by { |fixture| fixture[:stage] }
      .values
      .map { |fixtures| fixtures.map { |f| Time.iso8601(f[:kickoff_at]) } }
      .map { |kickoffs| kickoffs.max - kickoffs.min }
      .max
  end

  test "the rulebook's lock scope covers a multi-day slate" do
    span = widest_seeded_slate_span

    get turf_totals_v1_path
    assert_response :success
    lock_text = scoped_text("lock-rules")

    if span > 1.day
      refute_match(/later in the day/i, lock_text,
                   "the widest seeded slate spans #{(span / 1.day.to_f).round(1)} days, so " \
                   "scoping finality to \"later in the day\" understates the lock window — a " \
                   "player whose match is days out can infer it does not reach them")
      assert_match(/later in the contest/i, lock_text,
                   "the lock scope must reach the whole contest, not one day of it")
    end
  end

  # ── the PRE-LOCK window, measured off the PRODUCTION contest shape ───────
  # The Terms of Service is the one lock-scope surface a player can hold the
  # operator to, and it carries a per-game carve-out: "picks whose real-world
  # games have already kicked off cannot be changed". Whether that clause is
  # live is NOT a question about the contest lock. It is a question about the
  # window BEFORE it.
  #
  # Contest#locks_at is `starts_at || slate.first_game_starts_at ||
  # slate.starts_at` (contest.rb:686-693): an explicit starts_at WINS, it is
  # admin-permitted on contest create AND edit (contests_controller.rb:2702,
  # 2737), and NOTHING validates it against the slate's first kickoff. That is
  # not a corner case — measured against production on 2026-09-07, all 7
  # contests set starts_at by hand, so the derived case the tests above pin is
  # the case production never takes.
  #
  # Set the stated start time later than a game on the slate and the contest is
  # OPEN and UNLOCKED while that game is underway. The contest-wide gate has
  # not fired; the per-game gate has (entry.rb:44 in toggle_selection!, :95 in
  # update_picks!, :142 in assert_enterable!). One pick is frozen and its
  # neighbour is not, which is exactly what the carve-out exists to say.
  #
  # MEASURED, NOT ASSERTED. If Contest ever derives or validates starts_at
  # against the first kickoff, the asymmetry vanishes, this measurement flips,
  # and the test demands the carve-out be DELETED from the binding page.
  def admin_scheduled_contest
    @admin_scheduled_contest ||= Contest.create!(
      name: "Admin Scheduled Contest", slug: "admin-scheduled-contest",
      entry_fee_cents: 1900, status: "open", max_entries: 29,
      contest_type: "standard", slate: @slate,
      starts_at: @late_kickoff + 1.hour
    )
  end

  # Swap `out_matchup` for `in_matchup` on a SUBMITTED entry through the exact
  # path the clause describes — the contest page's edit action, which reaches
  # Entry#update_picks! — then roll it back. Answers only "was it allowed".
  # The id list is rebuilt from @picked rather than the association so a
  # rolled-back attempt cannot leave a stale set behind for the next one.
  def swap_accepted?(entry, out_matchup, in_matchup)
    entry.reload
    ids = (@picked - [out_matchup]).map(&:id) + [in_matchup.id]
    Entry.transaction do
      entry.update_picks!(ids)
      raise ActiveRecord::Rollback
    end
    true
  rescue StandardError
    false
  end

  # Returns the pair the carve-out turns on, read at ONE instant: is a pick
  # whose own game has kicked off frozen while a pick whose game has not is
  # still editable, with the contest open and its lock still in the future?
  def pre_lock_pick_freeze
    contest = admin_scheduled_contest
    entry = Entry.create!(user: users(:alex), contest: contest, status: "active")
    @picked.each { |m| entry.selections.create!(slate_matchup: m) }

    # The instant to read at is DERIVED from the contest, never hard-coded, so
    # both answers stay reachable. Just after the first kickoff is where the
    # asymmetry lives — but only while the contest is still unlocked, so on a
    # contest whose stated start does NOT trail its slate we fall back to just
    # before its lock. Pin it to `@early_kickoff + 1.minute` instead and the
    # "no asymmetry" branch below becomes unreachable dead code.
    instant = [@early_kickoff + 1.minute, contest.locks_at - 1.minute].min

    frozen = editable = nil
    travel_to instant do
      assert contest.open?, "measurement: the contest must still be open"
      assert_operator contest.locks_at, :>, Time.current,
                      "measurement: the contest lock must still be in the future — this is the " \
                      "pre-lock window, not the post-lock one the tests above measure"
      refute @spare_late.first.locked?,
             "measurement: the late wave must NOT have kicked off yet"

      frozen = !swap_accepted?(entry, @early_matchups.first, @spare_late.first)
      editable = swap_accepted?(entry, @picked.last, @spare_late.last)
    end

    [frozen, editable]
  end

  test "the Terms editing clause matches the pre-lock window Entry enforces" do
    frozen, editable = pre_lock_pick_freeze

    # CONTROL. Without it a refusal below could come from a dead entry, a full
    # slate, or a contest that is simply closed, and this test would certify any
    # Terms text at all. A pick whose game has not started must be swappable at
    # the very same instant, or the refusal is not the per-game gate talking.
    assert editable,
           "control: with the contest open and its lock still ahead, swapping a pick whose " \
           "game has NOT kicked off must be accepted"

    get terms_path
    assert_response :success
    clause = scoped_text("terms-entry-editing")

    if frozen
      # Measured reality: while the contest is OPEN, a kicked-off pick is
      # refused and its neighbour is accepted. The binding page must carry the
      # carve-out, or it promises a paying entrant an edit the code refuses.
      assert_match(/already kicked off/i, clause,
                   "Entry REFUSED a swap of a kicked-off pick while the contest was open and " \
                   "unlocked, and ACCEPTED a swap of one whose game had not started — the " \
                   "Terms editing clause must carry that carve-out")
      assert_match(/change/i, clause,
                   "the clause must still state that picks are editable while the contest is open")
      assert_match(/locks/i, clause, "the clause must name the contest lock")
      assert_match(/final/i, clause, "the clause must say entries are final after the lock")
    else
      # The asymmetry is gone: starts_at is now derived from, or validated
      # against, the slate's first kickoff, so no pick is ever frozen on the
      # strength of its own kickoff alone. The carve-out is then vestigial and
      # must come OFF the binding page — a clause that can never operate is a
      # clause that misleads.
      refute_match(/already kicked off/i, clause,
                   "no pick is frozen on its own kickoff any more, so the carve-out can never " \
                   "be the operative reason an edit is refused — remove it from Terms")
    end
  end

  # ── the PRE-LOCK SWAP WINDOW, as the two RULEBOOKS publish it ─────────────
  # Terms is the surface a player can hold the operator to; these two are the
  # ones a player actually reads, and both made the SAME promise in plainer
  # words: "you can swap any of your six teams as often as you like" until the
  # contest locks. Unqualified, that covers a team whose own match is already
  # underway — precisely the swap pre_lock_pick_freeze proves Entry refuses.
  #
  # They CONSUME the measurement above rather than restating it. Contest#locks_at
  # and SlateMatchup#locked? never branch on sport, so the one fifa-slate
  # measurement certifies the NFL rulebook too; a second fixture would only give
  # the two pages a way to disagree about the same code.
  #
  # BOTH BRANCHES ARE LIVE, and that is the point of measuring instead of
  # grepping. If Contest ever derives or validates starts_at against the slate's
  # first kickoff, the asymmetry vanishes, `frozen` goes false, and the qualifier
  # becomes a caveat that can never operate — a restriction the page claims and
  # the code no longer applies. The else branch then demands it come back OUT.
  # Without it, a fixed model would leave these pages quietly stale instead.
  SWAP_WINDOW_QUALIFIER = /swap[^.]*\bhas not (?:yet )?kicked off/i

  # The promise the qualifier replaced, in both the shapes the pages carried it.
  UNQUALIFIED_SWAP_PROMISES = {
    /as often as you like/i => "promises an unlimited pre-lock swap window",
    /swap any of your six teams/i => "promises every team is swappable pre-lock"
  }.freeze

  def assert_rulebook_swap_window_matches_measurement(page_path)
    frozen, editable = pre_lock_pick_freeze

    # CONTROL. Without it the refusal below could come from a dead entry, a
    # closed contest, or a full slate, and this test would certify any copy at
    # all. A pick whose match has NOT started must be swappable at the very same
    # instant, or the refusal is not the per-game gate talking.
    assert editable,
           "control: with the contest open and its lock still ahead, swapping a pick whose " \
           "match has NOT kicked off must be accepted"

    get page_path
    assert_response :success

    # scoped_text asserts the node before reading it. A renamed or deleted
    # section then fails HERE, loudly, instead of handing the assertions below
    # an empty string they would all pass against having read nothing.
    lock_text = scoped_text("lock-rules")
    assert_match(/swap/i, lock_text,
                 "the lock section must still tell a player when picks can be swapped")

    if frozen
      assert_match(SWAP_WINDOW_QUALIFIER, lock_text,
                   "Entry REFUSED a swap of a pick whose own match had kicked off while the " \
                   "contest was open and its lock still ahead, and ACCEPTED a swap of one whose " \
                   "match had not — so the rulebook's pre-lock swap sentence must scope itself " \
                   "to teams that have not kicked off")

      UNQUALIFIED_SWAP_PROMISES.each do |pattern, why|
        refute_match(pattern, lock_text,
                     "rulebook copy matching #{pattern.inspect} #{why}, but Entry#update_picks! " \
                     "raises for a pick whose own match has already kicked off, with the " \
                     "contest still open and Contest#locks_at still in the future")
      end
    else
      # starts_at is now derived from, or validated against, the slate's first
      # kickoff: no pick is ever frozen on the strength of its own kickoff
      # alone, so every team really is swappable until the contest locks.
      refute_match(SWAP_WINDOW_QUALIFIER, lock_text,
                   "no pick is frozen on its own kickoff any more, so scoping the swap window " \
                   "to teams whose match has not started describes a restriction the code no " \
                   "longer applies — take the qualifier back out of the rulebook")
    end
  end

  test "the World Cup rulebook's pre-lock swap window matches what Entry enforces" do
    assert_rulebook_swap_window_matches_measurement(turf_totals_v1_path)
  end

  test "the NFL rulebook's pre-lock swap window matches what Entry enforces" do
    assert_rulebook_swap_window_matches_measurement(turf_monster_v1_path)
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
