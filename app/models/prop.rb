class Prop < ApplicationRecord
  include Sluggable

  belongs_to :contest
  belongs_to :team, foreign_key: :team_slug, primary_key: :slug, optional: true
  belongs_to :opponent_team, class_name: "Team", foreign_key: :opponent_team_slug, primary_key: :slug, optional: true
  belongs_to :game, foreign_key: :game_slug, primary_key: :slug, optional: true
  has_many :picks, dependent: :destroy

  validates :description, presence: true
  validates :line, presence: true

  enum :status, { pending: "pending", graded: "graded" }

  def name_slug
    "#{description.parameterize}-#{line}"
  end
end
