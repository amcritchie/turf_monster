class UsersController < ApplicationController
  before_action :require_admin, only: [:add_funds]

  def add_funds
    rescue_and_log(target: current_user) do
      current_user.add_funds!(100_00)
      TransactionLog.record!(user: current_user, type: "admin_credit", amount_cents: 100_00, direction: "credit", description: "Admin credit $100.00")
      redirect_back fallback_location: root_path, notice: "Added $100 to your balance."
    end
  rescue StandardError => e
    redirect_back fallback_location: root_path, alert: "Failed to add funds."
  end
end
