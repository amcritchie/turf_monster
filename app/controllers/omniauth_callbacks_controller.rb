class OmniauthCallbacksController < ApplicationController
  skip_before_action :require_authentication

  def create
    user = User.from_omniauth(request.env["omniauth.auth"])
    session[:user_id] = user.id
    redirect_to root_path, notice: "Signed in with Google!"
  end

  def failure
    redirect_to login_path, alert: "Google sign-in failed. Please try again."
  end
end
