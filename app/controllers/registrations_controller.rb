class RegistrationsController < ApplicationController
  skip_before_action :require_authentication

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    @user.balance_cents = 0
    if @user.save
      session[:user_id] = @user.id
      redirect_to root_path, notice: "Welcome to Turf Monster, #{@user.display_name}!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
