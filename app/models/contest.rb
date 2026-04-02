class Contest < ApplicationRecord
  include Sluggable

  has_many :entries, dependent: :destroy
  belongs_to :slate

  validates :name, presence: true

  enum :status, { draft: "draft", open: "open", locked: "locked", settled: "settled" }

  def matchups
    slate.slate_matchups
  end

  def picks_required
    5
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

  PAYOUTS = { 1 => 40_00, 2 => 40_00, 3 => 40_00, 4 => 40_00, 5 => 40_00, 6 => 40_00 }
  BONUS = 50_00

  def grade!
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
          total_prize = spanned_ranks.sum { |r| PAYOUTS[r] || 0 }
          # Add bonus for rank 1
          total_prize += BONUS if rank == 1
          share = total_prize / tied_count
          if share > 0
            entry.user.add_funds!(share)
            TransactionLog.record!(user: entry.user, type: "payout", amount_cents: share, direction: "credit", source: self, description: "Payout rank ##{rank} for #{name}")
          end
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

    transaction do
      # Simulate all pending games
      matchups.pending.includes(:game).each do |matchup|
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
      grade!
    end
  end

  def fill!(users:)
    raise "Contest is not open" unless open?

    matchup_ids = matchups.pluck(:id)
    raise "Need at least #{picks_required} matchups" if matchup_ids.size < picks_required

    active_count = entries.where(status: [:active, :complete]).count
    slots = (max_entries || 15) - active_count
    return if slots <= 0

    existing_combos = entries.where(status: [:active, :complete]).includes(:selections).map do |entry|
      entry.selections.map(&:slate_matchup_id).sort
    end.to_set

    user_cycle = users.cycle
    attempts = 0

    slots.times do
      combo = nil
      loop do
        attempts += 1
        break if attempts > slots * 100
        # Pick 5 random non-locked matchups
        available = matchups.reject(&:locked?).map(&:id)
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
        entry.selections.create!(slate_matchup_id: matchup_id)
      end
      entry.confirm!
    end
  end

  def reset!
    transaction do
      entries.destroy_all
      matchups.update_all(goals: nil, status: "pending")
      matchups.includes(:game).find_each do |matchup|
        matchup.game&.update!(home_score: nil, away_score: nil, status: "scheduled")
      end
      update!(status: :open)
    end
  end

  def simulate_next_game!
    raise "Contest is already settled" if settled?

    # Find next unplayed game (by kickoff_at)
    matchup = matchups.pending.includes(:game).select { |m| m.game.present? }
      .sort_by { |m| m.game.kickoff_at || Time.current }
      .first

    raise "No pending games to simulate" unless matchup

    game = matchup.game
    home_score = rand(0..5)
    away_score = rand(0..5)
    game.update!(home_score: home_score, away_score: away_score, status: "completed")

    # Update all matchups for this game
    game_matchups = matchups.where(game_slug: game.slug)
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
    entries.where(status: [:active, :complete]).includes(selections: :slate_matchup).find_each do |entry|
      entry.selections.each(&:compute_points!)
      total = entry.selections.reload.sum { |s| s.points || 0 }
      entry.update!(score: total)
    end
  end

  # --- Onchain ---

  def onchain?
    onchain_contest_id.present?
  end

  def create_onchain!
    return if onchain?
    vault = Solana::Vault.new
    payout_bps = PAYOUTS.values.map { |c| (c * 100 / entry_fee_cents).to_i }
    bonus = Solana::Config.dollars_to_lamports(BONUS / 100.0)

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
