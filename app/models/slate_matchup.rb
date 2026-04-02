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

  # ─── Centralized Formulas ───────────────────────────────────
  # JS mirrors live in show.html.erb and formula_report.html.erb

  def self.multiplier_for(rank, n)
    (1.0 + 3.0 * Math.log(rank) / Math.log(n)).round(1)
  end

  def self.dk_score_for(line, over_odds)
    return nil unless line && over_odds
    prob = if over_odds < 0
      over_odds.abs.to_f / (over_odds.abs + 100)
    else
      100.0 / (over_odds + 100)
    end
    [(line - 0.5) + (prob - 0.5) * 3, 0].max.round(2)
  end

  def self.goals_distribution_for(rank, n)
    (0.2 + 4.3 * Math.log(n.to_f / rank) / Math.log(n)).round(2)
  end

  # ─── Instance Methods ───────────────────────────────────────

  def locked?
    game&.kickoff_at.present? && game.kickoff_at <= Time.current
  end

  def compute_multiplier!(n = nil)
    return unless rank.present?
    n ||= slate.slate_matchups.count
    update!(multiplier: self.class.multiplier_for(rank, n))
  end

  def name_slug
    "#{team_slug}-vs-#{opponent_team_slug}"
  end
end
