class OmniauthCallbacksController < ApplicationController
  include UserMergeable

  skip_before_action :require_authentication

  def create
    auth = request.env["omniauth.auth"]

    # Linking from /account while logged in
    if logged_in?
      existing = User.find_by(provider: auth.provider, uid: auth.uid)
      if existing && existing.id != current_user.id
        rescue_and_log(target: current_user, parent: existing) do
          merge_users!(survivor: current_user, absorbed: existing)
          redirect_to account_path, notice: "Google account linked and accounts merged."
        end
      else
        rescue_and_log(target: current_user) do
          current_user.update!(provider: auth.provider, uid: auth.uid)
          redirect_to account_path, notice: "Google account linked."
        end
      end
    else
      # Normal login/signup flow
      user = User.from_omniauth(auth)
      rescue_and_log(target: user) do
        set_app_session(user)
        redirect_to root_path, notice: "Signed in with Google!"
      end
    end
  rescue StandardError => e
    redirect_to (logged_in? ? account_path : login_path), alert: "Google sign-in failed. Please try again."
  end

  def failure
    redirect_to login_path, alert: "Google sign-in failed. Please try again."
  end
end
