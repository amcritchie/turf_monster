class Contest < ApplicationRecord
  include Sluggable

  has_many :props, dependent: :destroy
  has_many :entries, dependent: :destroy
  has_many :contest_matchups, dependent: :destroy

  validates :name, presence: true

  enum :status, { draft: "draft", open: "open", locked: "locked", settled: "settled" }

  def turf_totals?
    contest_type == "turf_totals"
  end

  def over_under?
    contest_type == "over_under"
  end

  def picks_required
    turf_totals? ? 5 : 4
  end

  def entry_fee_dollars
    entry_fee_cents / 100.0
  end

  def pool_cents
    entries.where(status: [:active, :complete]).count * entry_fee_cents
  end

  def pool_dollars
    pool_cents / 100.0
  end

  PAYOUTS = { 1 => 100_00, 2 => 40_00, 3 => 40_00, 4 => 40_00, 5 => 40_00 }
  TURF_TOTALS_PAYOUTS = { 1 => 40_00, 2 => 40_00, 3 => 40_00, 4 => 40_00, 5 => 40_00, 6 => 40_00 }
  TURF_TOTALS_BONUS = 50_00

  def grade!
    return grade_turf_totals! if turf_totals?

    transaction do
      props.each do |prop|
        next unless prop.result_value.present?
        prop.update!(status: "graded")
      end

      entries.active.includes(picks: :prop).find_each do |entry|
        total = entry.picks.sum { |pick| pick.compute_result }
        entry.update!(score: total, status: "complete")
      end

      ranked = entries.complete.order(score: :desc).includes(:user).to_a
      return update!(status: "settled") if ranked.empty?

      # Build ranks array (ties get same rank, next rank skips)
      ranks = []
      ranked.each_with_index do |entry, i|
        rank = if i == 0
          1
        elsif entry.score < ranked[i - 1].score
          i + 1
        else
          ranks.last
        end
        ranks << rank
      end

      # Pay out by rank groups and persist rank + payout on each entry
      ranked.each_with_index do |entry, i|
        rank = ranks[i]
        share = 0

        if rank <= 5
          tied_indices = ranks.each_index.select { |j| ranks[j] == rank }
          tied_count = tied_indices.size
          spanned_ranks = (rank..(rank + tied_count - 1)).to_a
          total_prize = spanned_ranks.sum { |r| PAYOUTS[r] || 0 }
          share = total_prize / tied_count
          entry.user.add_funds!(share) if share > 0
        end

        entry.update!(rank: rank, payout_cents: share)
      end

      update!(status: "settled")

      # Attempt onchain settlement (non-blocking)
      settle_onchain! if onchain?
    end
  end

  def jump!
    raise "Contest is already settled" if settled?

    if turf_totals?
      return jump_turf_totals!
    end

    transaction do
      props.includes(:game).each do |prop|
        game = prop.game
        next unless game

        # 50/50 coin flip: result lands above or below the line
        if [true, false].sample
          result = prop.line + rand(1..3) # over
        else
          result = [prop.line - rand(1..2), 0].max # under
        end

        home_score = (result / 2.0).ceil.to_i
        away_score = (result - home_score).to_i
        game.update!(home_score: home_score, away_score: away_score, status: "completed")
        prop.update!(result_value: result)
      end

      update!(status: :locked) if open?
      grade!
    end
  end

  def fill!(users:)
    return fill_turf_totals!(users: users) if turf_totals?

    raise "Contest is not open" unless open?

    prop_ids = props.pluck(:id)
    raise "Need at least 4 props" if prop_ids.size < 4

    existing_combos = entries.where(status: [:active, :complete]).includes(:picks).map do |entry|
      entry.picks.map { |p| [p.prop_id, p.selection] }.sort
    end.to_set

    active_count = entries.where(status: [:active, :complete]).count
    slots = (max_entries || 15) - active_count
    return if slots <= 0

    user_cycle = users.cycle
    attempts = 0

    slots.times do
      combo = nil
      loop do
        attempts += 1
        break if attempts > slots * 100 # safety valve
        four_props = prop_ids.sample(4)
        combo = four_props.map { |pid| [pid, ["more", "less"].sample] }.sort
        break unless existing_combos.include?(combo)
        combo = nil
      end
      break unless combo

      existing_combos << combo
      user = user_cycle.next
      entry = entries.create!(user: user, contest: self)
      combo.each do |prop_id, selection|
        entry.picks.create!(prop_id: prop_id, selection: selection)
      end
      entry.confirm!
    end
  end

  def reset!
    transaction do
      entries.destroy_all
      if turf_totals?
        contest_matchups.update_all(goals: nil, status: "pending")
        contest_matchups.includes(:game).find_each do |matchup|
          matchup.game&.update!(home_score: nil, away_score: nil, status: "scheduled")
        end
      else
        props.update_all(result_value: nil, status: "pending")
        props.includes(:game).find_each do |prop|
          prop.game&.update!(home_score: nil, away_score: nil, status: "scheduled")
        end
      end
      update!(status: :open)
    end
  end

  def jump_turf_totals!
    transaction do
      # Simulate all pending games
      contest_matchups.pending.includes(:game).each do |matchup|
        game = matchup.game
        next unless game

        unless game.status == "completed"
          home_score = rand(0..5)
          away_score = rand(0..5)
          game.update!(home_score: home_score, away_score: away_score, status: "completed")
        end

        if matchup.team_slug == game.home_team_slug
          matchup.update!(goals: game.home_score, status: "completed")
        elsif matchup.team_slug == game.away_team_slug
          matchup.update!(goals: game.away_score, status: "completed")
        end
      end

      update!(status: :locked) if open?
      grade_turf_totals!
    end
  end

  def simulate_next_game!
    raise "Contest is already settled" if settled?

    # Find next unplayed game (by kickoff_at)
    matchup = contest_matchups.pending.includes(:game).select { |m| m.game.present? }
      .sort_by { |m| m.game.kickoff_at || Time.current }
      .first

    raise "No pending games to simulate" unless matchup

    game = matchup.game
    home_score = rand(0..5)
    away_score = rand(0..5)
    game.update!(home_score: home_score, away_score: away_score, status: "completed")

    # Update all matchups for this game
    game_matchups = contest_matchups.where(game_slug: game.slug)
    game_matchups.each do |m|
      # Figure out which team's goals to record
      if m.team_slug == game.home_team_slug
        m.update!(goals: home_score, status: "completed")
      elsif m.team_slug == game.away_team_slug
        m.update!(goals: away_score, status: "completed")
      end
    end

    # Recompute points for all entries with selections on these matchups
    score_entries!
    game
  end

  def score_entries!
    entries.where(status: [:active, :complete]).includes(selections: :contest_matchup).find_each do |entry|
      entry.selections.each(&:compute_points!)
      total = entry.selections.reload.sum { |s| s.points || 0 }
      entry.update!(score: total)
    end
  end

  def grade_turf_totals!
    transaction do
      score_entries!

      ranked = entries.where(status: [:active, :complete]).order(score: :desc).includes(:user).to_a
      ranked.each { |e| e.update!(status: "complete") if e.active? }
      ranked = entries.complete.order(score: :desc).includes(:user).to_a

      return update!(status: "settled") if ranked.empty?

      # Build ranks (ties get same rank)
      ranks = []
      ranked.each_with_index do |entry, i|
        rank = if i == 0
          1
        elsif entry.score < ranked[i - 1].score
          i + 1
        else
          ranks.last
        end
        ranks << rank
      end

      # Pay out: top 6 get $40 each, rank 1 gets $50 bonus
      ranked.each_with_index do |entry, i|
        rank = ranks[i]
        share = 0

        if rank <= 6
          tied_indices = ranks.each_index.select { |j| ranks[j] == rank }
          tied_count = tied_indices.size
          spanned_ranks = (rank..(rank + tied_count - 1)).to_a
          total_prize = spanned_ranks.sum { |r| TURF_TOTALS_PAYOUTS[r] || 0 }
          # Add bonus for rank 1
          total_prize += TURF_TOTALS_BONUS if rank == 1
          share = total_prize / tied_count
          entry.user.add_funds!(share) if share > 0
        end

        entry.update!(rank: rank, payout_cents: share)
      end

      update!(status: "settled")

      # Attempt onchain settlement (non-blocking)
      settle_onchain! if onchain?
    end
  end

  def fill_turf_totals!(users:)
    raise "Contest is not open" unless open?

    matchup_ids = contest_matchups.pluck(:id)
    raise "Need at least #{picks_required} matchups" if matchup_ids.size < picks_required

    active_count = entries.where(status: [:active, :complete]).count
    slots = (max_entries || 15) - active_count
    return if slots <= 0

    existing_combos = entries.where(status: [:active, :complete]).includes(:selections).map do |entry|
      entry.selections.map(&:contest_matchup_id).sort
    end.to_set

    user_cycle = users.cycle
    attempts = 0

    slots.times do
      combo = nil
      loop do
        attempts += 1
        break if attempts > slots * 100
        # Pick 5 random non-locked matchups
        available = contest_matchups.reject(&:locked?).map(&:id)
        next if available.size < picks_required
        combo = available.sample(picks_required).sort
        break unless existing_combos.include?(combo)
        combo = nil
      end
      break unless combo

      existing_combos << combo
      user = user_cycle.next
      entry = entries.create!(user: user, contest: self)
      combo.each do |matchup_id|
        entry.selections.create!(contest_matchup_id: matchup_id)
      end
      entry.confirm!
    end
  end

  # --- Onchain ---

  def onchain?
    onchain_contest_id.present?
  end

  def create_onchain!
    return if onchain?
    vault = Solana::Vault.new
    payout_bps = turf_totals? ? TURF_TOTALS_PAYOUTS.values.map { |c| (c * 100 / entry_fee_cents).to_i } : PAYOUTS.values.map { |c| (c * 100 / entry_fee_cents).to_i }
    bonus = turf_totals? ? Solana::Config.dollars_to_lamports(TURF_TOTALS_BONUS / 100.0) : 0

    result = vault.create_contest(
      slug,
      entry_fee: Solana::Config.dollars_to_lamports(entry_fee_dollars),
      max_entries: max_entries || 100,
      payout_bps: payout_bps,
      bonus: bonus
    )

    update!(
      onchain_contest_id: result[:pda],
      onchain_tx_signature: result[:signature]
    )
  end

  def settle_onchain!
    return unless onchain? && !onchain_settled?

    winners = entries.complete.where("payout_cents > 0").includes(:user).map do |entry|
      {
        wallet: entry.user.solana_address,
        entry_num: entry.entry_number || 0,
        rank: entry.rank || 0,
        payout: Solana::Config.dollars_to_lamports(entry.payout_cents / 100.0)
      }
    end.select { |w| w[:wallet].present? }

    return update!(onchain_settled: true) if winners.empty?

    vault = Solana::Vault.new
    result = vault.settle_contest(slug, winners)
    update!(onchain_settled: true)
  rescue => e
    Rails.logger.error "Onchain settlement failed: #{e.message}"
    # Don't block DB settlement — onchain can be retried
  end

  def name_slug
    name.parameterize
  end
end
