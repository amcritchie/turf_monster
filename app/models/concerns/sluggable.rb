module Sluggable
  extend ActiveSupport::Concern

  included do
    before_save :set_slug
  end

  private

  def set_slug
    self.slug = name_slug
  end
end
