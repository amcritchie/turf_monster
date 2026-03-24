class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from StandardError, with: :handle_unexpected_error

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

  # Central error logging method — all controller error logging flows through here.
  # Returns the ErrorLog record so callers can attach target/parent context.
  def create_error_log(exception)
    ErrorLog.capture!(exception)
  end

  # Layer 2: Opt-in per-action wrapper with target/parent context.
  # Sets @_error_logged flag so Layer 1 won't double-log.
  def rescue_and_log(target: nil, parent: nil)
    yield
  rescue ActiveRecord::RecordNotFound => e
    raise e
  rescue StandardError => e
    error_log = create_error_log(e)
    if target
      error_log.target = target
      error_log.target_name = target.slug
    end
    if parent
      error_log.parent = parent
      error_log.parent_name = parent.slug
    end
    error_log.save!
    @_error_logged = true
    raise e
  end

  # Layer 1: Catch-all for RecordNotFound — 404 redirect, no logging.
  def handle_not_found(exception)
    respond_to do |format|
      format.html { redirect_to root_path, alert: "Not found" }
      format.json { render json: { error: "Not found" }, status: :not_found }
    end
  end

  # Layer 1: Catch-all for unexpected errors — log + friendly response.
  # Skips logging if rescue_and_log already captured it.
  def handle_unexpected_error(exception)
    create_error_log(exception) unless @_error_logged
    raise exception if Rails.env.development? || Rails.env.test?

    respond_to do |format|
      format.html { redirect_to root_path, alert: "Something went wrong." }
      format.json { render json: { error: "Internal server error" }, status: :internal_server_error }
    end
  end
end
