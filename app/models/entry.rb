class Entry < ApplicationRecord
  include Sluggable

  after_create :update_slug_with_id

  belongs_to :user
  belongs_to :contest
  has_many :picks, dependent: :destroy
  has_many :selections, dependent: :destroy


  enum :status, { cart: "cart", active: "active", complete: "complete", abandoned: "abandoned" }

  def toggle_pick!(prop, selection)
    existing = picks.find_by(prop: prop)

    if existing
      if existing.selection == selection
        existing.destroy!
      else
        existing.update!(selection: selection)
      end
    elsif picks.count < 4
      picks.create!(prop: prop, selection: selection)
    else
      picks.order(created_at: :desc).first.destroy!
      picks.create!(prop: prop, selection: selection)
    end

    reload
    if picks.empty?
      destroy!
      return nil
    end

    picks.each_with_object({}) { |p, h| h[p.prop_id.to_s] = p.selection }
  end

  def toggle_selection!(contest_matchup)
    raise "Game has already started" if contest_matchup.locked?

    existing = selections.find_by(contest_matchup: contest_matchup)

    if existing
      existing.destroy!
    elsif selections.count < contest.picks_required
      selections.create!(contest_matchup: contest_matchup)
    else
      # Replace oldest selection
      selections.order(created_at: :asc).first.destroy!
      selections.create!(contest_matchup: contest_matchup)
    end

    reload
    if selections.empty?
      destroy!
      return nil
    end

    selections.each_with_object({}) { |s, h| h[s.contest_matchup_id.to_s] = true }
  end

  def confirm!
    raise "Contest is not open" unless contest.open?

    if contest.turf_totals?
      confirm_turf_totals!
    else
      confirm_over_under!
    end
  end

  def selection_data
    selections.includes(contest_matchup: :team).map do |s|
      { contest_matchup_id: s.contest_matchup_id, team_slug: s.contest_matchup.team_slug }
    end
  end

  private

  def confirm_over_under!
    raise "Exactly 4 picks required" unless picks.count == 4

    my_combo = picks.map { |p| [p.prop_id, p.selection] }.sort
    contest.entries.where(user: user, status: [:active, :complete]).find_each do |other|
      other_combo = other.picks.map { |p| [p.prop_id, p.selection] }.sort
      raise "You already have an entry with this exact pick combination" if other_combo == my_combo
    end

    transaction do
      user.deduct_funds!(contest.entry_fee_cents) if contest.entry_fee_cents > 0
      update!(status: :active)
    end
  end

  def confirm_turf_totals!
    raise "Exactly #{contest.picks_required} selections required" unless selections.count == contest.picks_required

    # Check no locked games
    selections.includes(contest_matchup: :game).each do |s|
      raise "#{s.contest_matchup.team.name}'s game has already started" if s.contest_matchup.locked?
    end

    # Sybil check
    my_combo = selections.map(&:contest_matchup_id).sort
    contest.entries.where(user: user, status: [:active, :complete]).find_each do |other|
      other_combo = other.selections.map(&:contest_matchup_id).sort
      raise "You already have an entry with this exact selection combination" if other_combo == my_combo
    end

    transaction do
      user.deduct_funds!(contest.entry_fee_cents) if contest.entry_fee_cents > 0
      update!(status: :active)
    end
  end

  def update_slug_with_id
    update_column(:slug, name_slug)
  end

  public

  def name_slug
    "#{user.name.parameterize}-#{contest.name_slug}-#{id}"
  end
end
