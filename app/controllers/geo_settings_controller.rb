class GeoSettingsController < ApplicationController
  before_action :require_admin

  def edit
    @geo_setting = GeoSetting.current
  end

  def update
    @geo_setting = GeoSetting.current

    rescue_and_log(target: @geo_setting) do
      @geo_setting.assign_attributes(geo_setting_params)
      @geo_setting.banned_states = params[:geo_setting][:banned_states]&.reject(&:blank?) || []
      @geo_setting.save!
      redirect_to admin_geo_path, notice: "Geo settings updated."
    end
  rescue StandardError => e
    redirect_to admin_geo_path, alert: "Failed to update: #{e.message}"
  end

  def toggle_override
    if session[:geo_override].present?
      session.delete(:geo_override)
      redirect_back fallback_location: root_path, notice: "GEO override cleared."
    else
      session[:geo_override] = "WA"
      redirect_back fallback_location: root_path, notice: "Simulating WA state."
    end
  end

  private

  def geo_setting_params
    params.require(:geo_setting).permit(:enabled)
  end
end
