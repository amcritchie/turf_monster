class SlateMatchup < ApplicationRecord
  include Sluggable

  belongs_to :slate
  belongs_to :team, foreign_key: :team_slug, primary_key: :slug
  belongs_to :opponent_team, class_name: "Team", foreign_key: :opponent_team_slug, primary_key: :slug, optional: true
  belongs_to :game, foreign_key: :game_slug, primary_key: :slug, optional: true

  has_many :selections, dependent: :destroy

  validates :team_slug, uniqueness: { scope: :slate_id }

  scope :ranked, -> { order(:rank) }
  scope :pending, -> { where(status: "pending") }
  scope :completed, -> { where(status: "completed") }

  def locked?
    game&.kickoff_at.present? && game.kickoff_at <= Time.current
  end

  def compute_multiplier!
    return unless rank.present?
    update!(multiplier: (Math.sqrt(rank) * 0.5 + 0.5).round(1))
  end

  def name_slug
    "#{team_slug}-vs-#{opponent_team_slug}"
  end
end
