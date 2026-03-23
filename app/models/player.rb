class Player < ApplicationRecord
  include Sluggable

  belongs_to :team, foreign_key: :team_slug, primary_key: :slug, optional: true

  validates :name, presence: true

  def name_slug
    name.parameterize
  end
end
