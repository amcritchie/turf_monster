class Contest < ApplicationRecord
  include Sluggable

  has_many :props, dependent: :destroy
  has_many :entries, dependent: :destroy

  validates :name, presence: true

  enum :status, { draft: "draft", open: "open", locked: "locked", settled: "settled" }

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

  def grade!
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
    end
  end

  def jump!
    raise "Contest is already settled" if settled?

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
      props.update_all(result_value: nil, status: "pending")
      props.includes(:game).find_each do |prop|
        prop.game&.update!(home_score: nil, away_score: nil, status: "scheduled")
      end
      update!(status: :open)
    end
  end

  def name_slug
    name.parameterize
  end
end
