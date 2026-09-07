module LandingPagesHelper
  # Funnel "how it works" steps, tailored to the wired contest's game type.
  # Falls back to Turf Totals when no contest is wired yet (draft preview).
  #
  # `game_type` is a TWO-value enum (contest.rb), so the else branch below is
  # not a niche default: it serves EVERY Turf Totals contest — currently the
  # NFL season — plus the no-contest preview. Keep its copy true for both, and
  # keep calendar dates out of it: this page is public and unauthenticated
  # (landing_pages_controller.rb skips require_authentication), so a hardcoded
  # date rots in front of real visitors.
  def funnel_how_it_works(contest)
    if contest&.world_cup_survivor?
      [
        ["Enter the contest", "One entry per player — claim your spot before the tournament locks."],
        ["Pick a team each round", "Back a different team every round. No team can be used twice."],
        ["Win or draw to survive", "A loss eliminates you. The last player standing takes the prize."]
      ]
    else
      required_picks = contest&.picks_required || Contest::TURF_TOTALS_DEFAULT_PICKS_REQUIRED
      [
        ["Pick #{required_picks} teams", "Choose #{required_picks} NFL teams for your entry."],
        ["Create Account", "Sign up with email or Google — it only takes a few seconds."],
        ["Submit Entry", "Confirm your #{required_picks} picks and submit your entry."],
        ["Contest Locks", "The contest locks when the first game kicks off. Picks are final after that."]
      ]
    end
  end
end
