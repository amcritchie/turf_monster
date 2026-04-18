class Selection < ApplicationRecord
  include Sluggable

  belongs_to :entry
  belongs_to :slate_matchup

  validates :slate_matchup_id, uniqueness: { scope: :entry_id }

  def compute_points!
    return unless slate_matchup.goals.present? && slate_matchup.turf_score.present?
    update!(points: slate_matchup.goals * slate_matchup.turf_score)
  end

  def name_slug
    "#{entry.slug}-#{slate_matchup.team_slug}"
  end
end
