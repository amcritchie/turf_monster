class UsersController < ApplicationController
  def add_funds
    current_user.add_funds!(100_00) # $100
    redirect_back fallback_location: root_path, notice: "Added $100 to your balance."
  end
end
