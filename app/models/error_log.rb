class ErrorLog < ApplicationRecord
  belongs_to :target, polymorphic: true, optional: true
  belongs_to :parent, polymorphic: true, optional: true

  def self.capture!(exception, target: nil, parent: nil)
    cleaned = Rails.backtrace_cleaner.clean(exception.backtrace || [])

    log = create!(
      message: exception.message,
      inspect: exception.inspect,
      backtrace: cleaned.to_json,
      target: target,
      target_name: target&.slug,
      parent: parent,
      parent_name: parent&.slug
    )
    log.update_column(:slug, "error-log-#{log.id}")
    log
  end
end
