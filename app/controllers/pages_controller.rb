class PagesController < ApplicationController
  skip_before_action :require_authentication

  def turf_totals_v1
  end
end
