class Entry < ApplicationRecord
  include Sluggable

  after_create :update_slug_with_id

  belongs_to :user
  belongs_to :contest
  has_many :picks, dependent: :destroy


  enum :status, { cart: "cart", active: "active", complete: "complete" }

  def toggle_pick!(prop, selection)
    existing = picks.find_by(prop: prop)

    if existing
      if existing.selection == selection
        existing.destroy!
      else
        existing.update!(selection: selection)
      end
    elsif picks.count < 3
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

  def confirm!
    raise "Contest is not open" unless contest.open?
    raise "Exactly 3 picks required" unless picks.count == 3
    transaction do
      user.deduct_funds!(contest.entry_fee_cents) if contest.entry_fee_cents > 0
      update!(status: :active)
    end
  end

  def name_slug
    "#{user.name.parameterize}-#{contest.name_slug}-#{id}"
  end

  private

  def update_slug_with_id
    update_column(:slug, name_slug)
  end
end
