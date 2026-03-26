class User < ApplicationRecord
  include Sluggable

  has_secure_password validations: false
  has_many :entries, dependent: :destroy

  validates :email, uniqueness: true, allow_nil: true
  validates :wallet_address, uniqueness: true, allow_nil: true
  validates :password, length: { minimum: 6 }, if: -> { password.present? }
  validates :password, confirmation: true, if: -> { password_confirmation.present? }
  validate :has_authentication_method

  before_save :set_name_parts, if: -> { name_changed? }
  before_save :normalize_wallet_address

  # --- Class methods ---

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

  def self.from_wallet(address)
    find_by(wallet_address: address.downcase)
  end

  def admin?
    admin
  end

  # --- Display ---

  def display_name
    name.presence || (email.present? ? email.split("@").first.capitalize : truncated_wallet) || "anon"
  end

  def truncated_wallet
    return nil unless wallet_address.present?
    "#{wallet_address[0..5]}...#{wallet_address[-4..]}"
  end

  # --- Predicates ---

  def wallet_connected?
    wallet_address.present?
  end

  def google_connected?
    provider == "google_oauth2" && uid.present?
  end

  def has_password?
    password_digest.present? && password_digest != ""
  end

  def has_email?
    email.present?
  end

  # --- Money ---

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

  def has_authentication_method
    return if email.present? || wallet_address.present? || (provider.present? && uid.present?)
    errors.add(:base, "Must have email, wallet address, or linked social account")
  end

  def set_name_parts
    parts = name.to_s.strip.split(" ")
    self.first_name = parts.first
    self.last_name = parts.last if parts.size > 1
  end

  def normalize_wallet_address
    self.wallet_address = wallet_address.downcase if wallet_address.present?
  end

  def name_slug
    base = name.presence || email.presence || wallet_address.presence || "user"
    "#{base}-#{id}".downcase.gsub(/\s+/, "-")
  end
end
