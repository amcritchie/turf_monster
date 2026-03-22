class Prop < ApplicationRecord
  belongs_to :contest
  has_many :picks, dependent: :destroy

  validates :description, presence: true
  validates :line, presence: true

  enum :status, { pending: "pending", graded: "graded" }
end
