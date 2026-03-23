class Pick < ApplicationRecord
  include Sluggable

  belongs_to :entry
  belongs_to :prop

  validates :selection, presence: true, inclusion: { in: %w[more less] }
  validates :prop_id, uniqueness: { scope: :entry_id }

  enum :result, { win: "win", loss: "loss", push: "push", pending: "pending" }

  def compute_result
    return 0 unless prop.result_value.present?

    if prop.result_value > prop.line
      winning_side = "more"
    elsif prop.result_value < prop.line
      winning_side = "less"
    else
      update!(result: "push")
      return 0.5
    end

    if selection == winning_side
      update!(result: "win")
      1.0
    else
      update!(result: "loss")
      0.0
    end
  end

  def name_slug
    "#{prop.description.parameterize}-#{selection}"
  end
end
