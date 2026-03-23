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

  def grade!
    transaction do
      props.each do |prop|
        next unless prop.result_value.present?
        prop.update!(status: "graded")
      end

      entries.active.includes(:picks).find_each do |entry|
        total = entry.picks.sum { |pick| pick.compute_result }
        entry.update!(score: total, status: "complete")
      end

      completed = entries.complete
      max_score = completed.maximum(:score)
      winners = completed.where(score: max_score)

      if winners.any? && pool_cents > 0
        share = pool_cents / winners.count
        winners.each do |entry|
          entry.user.add_funds!(share)
        end
      end

      update!(status: "settled")
    end
  end

  def name_slug
    name.parameterize
  end
end
