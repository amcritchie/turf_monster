class User < ApplicationRecord
  include Sluggable

  has_secure_password
  has_many :entries, dependent: :destroy

  validates :email, presence: true, uniqueness: true

  before_save :set_name_parts, if: -> { name_changed? }

  def self.from_omniauth(auth)
    # Returning Google user
    user = find_by(provider: auth.provider, uid: auth.uid)
    return user if user

    # Existing password user logging in with Google — link the account
    user = find_by(email: auth.info.email)
    if user
      user.update!(provider: auth.provider, uid: auth.uid)
      return user
    end

    # Brand new user via Google
    create!(
      email: auth.info.email,
      name: auth.info.name,
      provider: auth.provider,
      uid: auth.uid,
      password: SecureRandom.hex(16),
      balance_cents: 0
    )
  end

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

  private

  def set_name_parts
    parts = name.to_s.strip.split(" ")
    self.first_name = parts.first
    self.last_name = parts.last if parts.size > 1
  end

  def name_slug
    "#{name}-#{email}".downcase.gsub(/\s+/, "-")
  end
end
