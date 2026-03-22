class UsersController < ApplicationController
  def add_funds
    user = User.find(params[:id])
    user.add_funds!(100_00) # $100
    redirect_back fallback_location: root_path, notice: "Added $100 to #{user.name}'s balance."
  end
end
