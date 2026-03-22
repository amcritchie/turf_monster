class User < ApplicationRecord
  has_secure_password
  has_many :entries, dependent: :destroy

  validates :email, presence: true, uniqueness: true

  def display_name
    name.presence || email.split("@").first.capitalize
  end

  def balance_dollars
    balance_cents / 100.0
  end

  def add_funds!(cents)
    increment!(:balance_cents, cents)
  end

  def deduct_funds!(cents)
    raise "Insufficient funds" if balance_cents < cents
    decrement!(:balance_cents, cents)
  end
end
