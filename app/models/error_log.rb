class ErrorLog < ApplicationRecord
  belongs_to :target, polymorphic: true, optional: true
  belongs_to :parent, polymorphic: true, optional: true

  def to_param
    slug
  end

  def inspect_field
    read_attribute(:inspect)
  end


  def self.capture!(exception)
    cleaned = Rails.backtrace_cleaner.clean(exception.backtrace || [])

    log = create!(
      message: exception.message,
      inspect: exception.inspect,
      backtrace: cleaned.to_json
    )
    log.update_column(:slug, "error-log-#{log.id}")
    log
  end
end
