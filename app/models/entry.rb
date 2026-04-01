class Entry < ApplicationRecord
  include Sluggable

  after_create :update_slug_with_id

  belongs_to :user
  belongs_to :contest
  has_many :selections, dependent: :destroy

  enum :status, { cart: "cart", active: "active", complete: "complete", abandoned: "abandoned" }

  def toggle_selection!(slate_matchup)
    raise "Game has already started" if slate_matchup.locked?

    existing = selections.find_by(slate_matchup: slate_matchup)

    if existing
      existing.destroy!
    elsif selections.count < contest.picks_required
      selections.create!(slate_matchup: slate_matchup)
    else
      # Replace oldest selection
      selections.order(created_at: :asc).first.destroy!
      selections.create!(slate_matchup: slate_matchup)
    end

    reload
    if selections.empty?
      destroy!
      return nil
    end

    selections.each_with_object({}) { |s, h| h[s.slate_matchup_id.to_s] = true }
  end

  def confirm!
    raise "Contest is not open" unless contest.open?
    raise "Exactly #{contest.picks_required} selections required" unless selections.count == contest.picks_required

    # Check no locked games
    selections.includes(slate_matchup: :game).each do |s|
      raise "#{s.slate_matchup.team.name}'s game has already started" if s.slate_matchup.locked?
    end

    # Sybil check
    my_combo = selections.map(&:slate_matchup_id).sort
    contest.entries.where(user: user, status: [:active, :complete]).find_each do |other|
      other_combo = other.selections.map(&:slate_matchup_id).sort
      raise "You already have an entry with this exact selection combination" if other_combo == my_combo
    end

    transaction do
      user.deduct_funds!(contest.entry_fee_cents) if contest.entry_fee_cents > 0
      update!(status: :active)
    end
  end

  def selection_data
    selections.includes(slate_matchup: :team).map do |s|
      { slate_matchup_id: s.slate_matchup_id, team_slug: s.slate_matchup.team_slug }
    end
  end

  private

  def update_slug_with_id
    update_column(:slug, name_slug)
  end

  public

  # --- Onchain ---

  def enter_onchain!
    return unless contest.onchain? && user.solana_connected?

    # Assign entry number (per-user, per-contest counter)
    self.entry_number ||= contest.entries.where(user: user).where.not(entry_number: nil).count
    save! if entry_number_changed?

    vault = Solana::Vault.new
    result = vault.enter_contest(user.solana_address, contest.slug, entry_number)
    update!(
      onchain_entry_id: result[:entry_pda],
      onchain_tx_signature: result[:signature]
    )
  rescue => e
    Rails.logger.error "Onchain entry failed: #{e.message}"
    # Don't block DB entry — onchain can be retried
  end

  def onchain?
    onchain_entry_id.present?
  end

  def name_slug
    "#{user.name.parameterize}-#{contest.name_slug}-#{id}"
  end
end
