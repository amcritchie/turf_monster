class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :require_authentication

  helper_method :current_user, :logged_in?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    current_user.present?
  end

  def require_authentication
    unless logged_in?
      redirect_to login_path, alert: "Please log in to continue."
    end
  end

  def rescue_and_log(target: nil, parent: nil)
    yield
  rescue ActiveRecord::RecordNotFound => e
    raise e
  rescue StandardError => e
    ErrorLog.capture!(e, target: target, parent: parent)
    raise e
  end
end
