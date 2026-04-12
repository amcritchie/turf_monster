class ToastTestController < ApplicationController
  skip_before_action :require_authentication

  def index; end

  def trigger_flash
    type = %w[notice alert].include?(params[:type]) ? params[:type].to_sym : :notice
    flash[type] = params[:message] || "Test #{type} flash message"
    redirect_to toast_test_path
  end
end
