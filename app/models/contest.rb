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

      # Rank entries by score DESC with tie handling
      ranked = entries.complete.order(score: :desc).includes(:user).to_a
      return update!(status: "settled") if ranked.empty?

      # Assign ranks (ties get same rank, skip next)
      current_rank = 1
      ranked.each_with_index do |entry, i|
        if i > 0 && entry.score < ranked[i - 1].score
          current_rank = i + 1
        end
        entry.update_column(:rank, current_rank) if entry.respond_to?(:rank)
      end

      # Group by rank for payout calculation
      by_rank = ranked.group_by.with_index { |entry, i|
        rank = 1
        (0...i).each { |j| rank = j + 2 if ranked[j].score > entry.score }
        # Recalculate: first entry = rank 1, next different score = rank (count of higher + 1)
        rank
      }

      # Simpler: build rank array
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

      # Pay out by rank groups
      ranked.each_with_index do |entry, i|
        rank = ranks[i]
        next if rank > 5 # Only top 5 paid

        # Find all entries at this rank
        tied_indices = ranks.each_index.select { |j| ranks[j] == rank }
        tied_count = tied_indices.size

        # Sum prizes for all ranks these tied entries span
        spanned_ranks = (rank..(rank + tied_count - 1)).to_a
        total_prize = spanned_ranks.sum { |r| PAYOUTS[r] || 0 }
        share = total_prize / tied_count

        entry.user.add_funds!(share) if share > 0
      end

      update!(status: "settled")
    end
  end

  def fill!(users:)
    raise "Contest is not open" unless open?

    # Generate all possible 2-pick combos: [prop_id, selection] pairs
    # Exclude combos where both picks are on the same prop
    options = props.flat_map { |p| [[p.id, "more"], [p.id, "less"]] }
    all_combos = options.combination(2).reject { |a, b| a[0] == b[0] }.to_a

    # Exclude combos already used by active/complete entries
    existing_combos = entries.where(status: [:active, :complete]).includes(:picks).map do |entry|
      entry.picks.map { |p| [p.prop_id, p.selection] }.sort
    end.to_set

    available_combos = all_combos.map(&:sort).reject { |c| existing_combos.include?(c) }

    active_count = entries.where(status: [:active, :complete]).count
    slots = (max_entries || 15) - active_count
    return if slots <= 0

    combos_to_use = available_combos.first(slots)
    user_cycle = users.cycle

    combos_to_use.each do |combo|
      user = user_cycle.next
      entry = entries.create!(user: user, contest: self)
      combo.each do |prop_id, selection|
        entry.picks.create!(prop_id: prop_id, selection: selection)
      end
      entry.confirm!
    end
  end

  def name_slug
    name.parameterize
  end
end
