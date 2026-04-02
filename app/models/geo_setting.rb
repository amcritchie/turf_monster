class GeoSetting < ApplicationRecord
  include Sluggable

  validates :app_name, presence: true, uniqueness: true

  DEFAULT_BANNED_STATES = %w[WA ID MT LA AZ HI NV].freeze

  def self.current
    find_or_initialize_by(app_name: Studio.app_name)
  end

  def self.blocked?(state_code)
    return false if state_code.blank?
    setting = current
    setting.persisted? && setting.enabled? && setting.banned_states.include?(state_code)
  end

  def name_slug
    "geo-#{app_name.parameterize}"
  end
end
