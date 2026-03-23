class DraftPick < ApplicationRecord
  belongs_to :user
  belongs_to :contest

  validates :user_id, uniqueness: { scope: :contest_id }

  def self.save_draft(user, contest, picks_hash)
    if picks_hash.blank? || picks_hash.empty?
      clear_draft(user, contest)
      return nil
    end

    draft = find_or_initialize_by(user: user, contest: contest)
    draft.update!(picks: picks_hash)
    draft
  end

  def self.load_draft(user, contest)
    find_by(user: user, contest: contest)
  end

  def self.clear_draft(user, contest)
    find_by(user: user, contest: contest)&.destroy
  end
end
