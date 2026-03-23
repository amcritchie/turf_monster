class User < ApplicationRecord
  has_secure_password
  has_many :entries, dependent: :destroy
  has_many :draft_picks, dependent: :destroy

  validates :email, presence: true, uniqueness: true

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
end
