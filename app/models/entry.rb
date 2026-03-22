class Entry < ApplicationRecord
  belongs_to :user
  belongs_to :contest
  has_many :picks, dependent: :destroy

  validates :user_id, uniqueness: { scope: :contest_id }

  enum :status, { pending: "pending", scored: "scored" }
end
