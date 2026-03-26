class ApplicationController < ActionController::Base
  include Studio::ErrorHandling

  allow_browser versions: :modern

  private

  def require_admin
    return if logged_in? && current_user.admin?
    redirect_to root_path, alert: "Not authorized"
  end
end
