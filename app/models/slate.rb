class Slate < ApplicationRecord
  include Sluggable

  has_many :slate_matchups, dependent: :destroy
  has_many :contests

  validates :name, presence: true

  def name_slug
    name.parameterize
  end
end
