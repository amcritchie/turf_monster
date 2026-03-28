class Selection < ApplicationRecord
  include Sluggable

  belongs_to :entry
  belongs_to :contest_matchup

  validates :contest_matchup_id, uniqueness: { scope: :entry_id }

  def compute_points!
    return unless contest_matchup.goals.present? && contest_matchup.multiplier.present?
    update!(points: contest_matchup.goals * contest_matchup.multiplier)
  end

  def name_slug
    "#{entry.slug}-#{contest_matchup.team_slug}"
  end
end
