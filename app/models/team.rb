class Team < ApplicationRecord
  include Sluggable

  has_many :players, foreign_key: :team_slug, primary_key: :slug
  has_many :home_games, class_name: "Game", foreign_key: :home_team_slug, primary_key: :slug
  has_many :away_games, class_name: "Game", foreign_key: :away_team_slug, primary_key: :slug

  validates :name, presence: true

  def name_slug
    name.parameterize
  end
end
