class UsersController < ApplicationController
  def add_funds
    rescue_and_log(target: current_user) do
      current_user.add_funds!(100_00) # $100
      redirect_back fallback_location: root_path, notice: "Added $100 to your balance."
    end
  rescue StandardError => e
    redirect_back fallback_location: root_path, alert: "Failed to add funds."
  end
end
