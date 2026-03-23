class Game < ApplicationRecord
  include Sluggable

  belongs_to :home_team, class_name: "Team", foreign_key: :home_team_slug, primary_key: :slug
  belongs_to :away_team, class_name: "Team", foreign_key: :away_team_slug, primary_key: :slug

  has_many :props, foreign_key: :game_slug, primary_key: :slug

  def name_slug
    "#{home_team_slug}-vs-#{away_team_slug}"
  end
end
