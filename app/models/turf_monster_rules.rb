# The worked examples on /turf-monster-v1, as DATA rather than markup.
#
# WHY THIS IS NOT JUST TYPED INTO THE VIEW. The page's whole claim is that its
# numbers are the real ones, and a number typed into ERB is a number nobody can
# check. Here, only the INPUTS are written down — a team, its rank on the live
# Weeks 1-3 board, and (for the scoring example) the points it scored each week.
# Everything the page PRINTS is derived:
#
#   turf_score  <- SlateMatchup.turf_score_for(rank, 32, sport: "nfl"), the same
#                  curve that prices the real board
#   points      <- weekly_points.sum * turf_score, the same shape as
#                  Selection#compute_points! on a span slate
#
# So the multipliers cannot drift from the formula, the scoring table cannot add
# up wrong, and re-tuning the curve re-prices this page with the board.
#
# The RANKS are a snapshot of the live "NFL 2026 Weeks 1-3" slate (read
# 2026-09-06) — the one input that is asserted rather than derived. The weekly
# point totals are invented, and the page says so where it prints them.
module TurfMonsterRules
  # Every NFL slate ranks all 32 teams, which fixes the curve's denominator.
  TEAM_COUNT = 32

  # One team as the page presents it: who they are, where they sit on the board,
  # who they play, and — in the scoring example — what they scored.
  Example = Data.define(:team_slug, :rank, :opponent_slugs, :weekly_points) do
    # The multiplier, from the shipped curve. NEVER a typed number.
    def turf_score
      SlateMatchup.turf_score_for(rank, TurfMonsterRules::TEAM_COUNT, sport: "nfl")
    end

    # Points on the scoreboard, summed across the span — the unit an NFL
    # selection scores on (SlateMatchup#goals holds points for football).
    def points_scored
      weekly_points.sum
    end

    # What the entry is credited: span points times the frozen multiplier.
    def entry_points
      (points_scored * turf_score).round(1)
    end
  end

  # The card in "The Basics". Atlanta because a mid-pack team makes the point
  # better than either extreme: a real multiplier, three real opponents.
  FEATURE = Example.new(
    team_slug: "atlanta-falcons", rank: 26,
    opponent_slugs: %w[pittsburgh-steelers carolina-panthers green-bay-packers],
    weekly_points: [17, 27, 20]
  )

  # The six-team example entry, favorites through longshots, in board order.
  LINEUP = [
    Example.new(team_slug: "baltimore-ravens", rank: 2,
                opponent_slugs: %w[indianapolis-colts new-orleans-saints dallas-cowboys],
                weekly_points: [24, 31, 27]),
    Example.new(team_slug: "detroit-lions", rank: 3,
                opponent_slugs: %w[new-orleans-saints buffalo-bills new-york-jets],
                weekly_points: [20, 17, 34]),
    Example.new(team_slug: "buffalo-bills", rank: 8,
                opponent_slugs: %w[houston-texans detroit-lions los-angeles-chargers],
                weekly_points: [28, 21, 24]),
    Example.new(team_slug: "houston-texans", rank: 15,
                opponent_slugs: %w[buffalo-bills cincinnati-bengals indianapolis-colts],
                weekly_points: [13, 20, 23]),
    FEATURE,
    Example.new(team_slug: "arizona-cardinals", rank: 32,
                opponent_slugs: %w[los-angeles-chargers seattle-seahawks san-francisco-49ers],
                weekly_points: [10, 23, 17])
  ].freeze

  # The three points on the curve section 03 names: both ends and the middle.
  CURVE = [
    { team_slug: "san-francisco-49ers", rank: 1,  note: "Safest points, smallest multiplier" },
    { team_slug: "jacksonville-jaguars", rank: 16, note: "Middle of the board, balanced" },
    { team_slug: "arizona-cardinals",    rank: 32, note: "Every point counts double" }
  ].freeze

  # The scoring example's footer total.
  def self.lineup_total
    LINEUP.sum(&:entry_points).round(1)
  end

  # Every team slug the page names — its own picks AND their opponents, because
  # the opponent chips wear the opponent's own brand color. One query, no N+1.
  def self.team_slugs
    (LINEUP + [FEATURE]).flat_map { |e| [e.team_slug, *e.opponent_slugs] }
      .concat(CURVE.map { |c| c[:team_slug] })
      .uniq
  end

  # The multiplier for a CURVE row, derived exactly as an Example's is.
  def self.turf_score_for_rank(rank)
    SlateMatchup.turf_score_for(rank, TEAM_COUNT, sport: "nfl")
  end
end
