class User < ApplicationRecord
  include Sluggable

  has_secure_password validations: false
  has_many :entries, dependent: :destroy

  validates :email, uniqueness: true, allow_nil: true
  validates :solana_address, uniqueness: true, allow_nil: true
  validates :password, length: { minimum: 6 }, if: -> { password.present? }
  validates :password, confirmation: true, if: -> { password_confirmation.present? }
  validate :has_authentication_method

  before_save :set_name_parts, if: -> { name_changed? }

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

  def self.from_solana_wallet(address)
    find_by(solana_address: address)
  end

  def admin?
    admin
  end

  # --- Display ---

  def display_name
    name.presence || (email.present? ? email.split("@").first.capitalize : nil) || truncated_solana || "anon"
  end

  def truncated_solana
    return nil unless solana_address.present?
    "#{solana_address[0..3]}...#{solana_address[-4..]}"
  end

  # --- Predicates ---

  def solana_connected?
    solana_address.present?
  end

  def custodial_wallet?
    wallet_type == "custodial"
  end

  def phantom_wallet?
    wallet_type == "phantom"
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

  # --- Solana wallet ---

  def solana_keypair
    return nil unless encrypted_solana_private_key.present?
    Solana::Keypair.from_encrypted(encrypted_solana_private_key)
  end

  def generate_custodial_wallet!
    return if solana_address.present?
    keypair = Solana::Keypair.generate
    update!(
      solana_address: keypair.to_base58,
      encrypted_solana_private_key: keypair.encrypt,
      wallet_type: "custodial"
    )
    keypair
  end

  # --- Money ---

  def balance_dollars
    balance_cents / 100.0
  end

  def promotional_dollars
    promotional_cents / 100.0
  end

  def total_balance_cents
    balance_cents + promotional_cents
  end

  def total_balance_dollars
    total_balance_cents / 100.0
  end

  def add_funds!(cents)
    increment!(:balance_cents, cents)
  end

  def add_promotional!(cents)
    increment!(:promotional_cents, cents)
  end

  def deduct_funds!(cents)
    raise "Insufficient funds" if total_balance_cents < cents
    promo_use = [promotional_cents, cents].min
    real_use = cents - promo_use
    transaction do
      decrement!(:promotional_cents, promo_use) if promo_use > 0
      decrement!(:balance_cents, real_use) if real_use > 0
    end
  end

  # Only real (onchain-backed) balance is withdrawable
  def withdrawable_cents
    balance_cents
  end

  def withdrawable_dollars
    withdrawable_cents / 100.0
  end

  private

  def has_authentication_method
    return if email.present? || solana_address.present? || (provider.present? && uid.present?)
    errors.add(:base, "Must have email, Solana address, or linked social account")
  end

  def set_name_parts
    parts = name.to_s.strip.split(" ")
    self.first_name = parts.first
    self.last_name = parts.last if parts.size > 1
  end

  def name_slug
    base = name.presence || email.presence || solana_address.presence || "user"
    "#{base}-#{id}".downcase.gsub(/\s+/, "-")
  end
end
