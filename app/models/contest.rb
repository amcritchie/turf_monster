class Contest < ApplicationRecord
  has_many :props, dependent: :destroy
  has_many :entries, dependent: :destroy

  validates :name, presence: true

  enum :status, { draft: "draft", open: "open", locked: "locked", settled: "settled" }

  def entry_fee_dollars
    entry_fee_cents / 100.0
  end

  def pool_cents
    entries.count * entry_fee_cents
  end

  def pool_dollars
    pool_cents / 100.0
  end

  def enter!(user, picks_params)
    raise "Contest is not open" unless open?
    raise "Already entered" if entries.exists?(user: user)
    raise "Contest is full" if max_entries.present? && entries.count >= max_entries

    picks_hash = picks_params.respond_to?(:to_unsafe_h) ? picks_params.to_unsafe_h : picks_params.to_h
    valid_picks = picks_hash.select { |_, v| v.present? }
    raise "Exactly 3 picks required" unless valid_picks.size == 3

    transaction do
      user.deduct_funds!(entry_fee_cents) if entry_fee_cents > 0
      entry = entries.create!(user: user)

      picks_params.each do |prop_id, selection|
        next if selection.blank?
        entry.picks.create!(prop_id: prop_id, selection: selection)
      end

      entry
    end
  end

  def grade!
    transaction do
      props.each do |prop|
        next unless prop.result_value.present?
        prop.update!(status: "graded")
      end

      entries.includes(:picks).find_each do |entry|
        total = entry.picks.sum { |pick| pick.compute_result }
        entry.update!(score: total, status: "scored")
      end

      max_score = entries.maximum(:score)
      winners = entries.where(score: max_score)

      if winners.any? && pool_cents > 0
        share = pool_cents / winners.count
        winners.each do |entry|
          entry.user.add_funds!(share)
        end
      end

      update!(status: "settled")
    end
  end
end
