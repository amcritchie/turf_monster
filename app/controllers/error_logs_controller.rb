class ErrorLogsController < ApplicationController
  skip_before_action :require_authentication

  def index
    @error_logs = ErrorLog.order(created_at: :desc).limit(100)
  end

  def show
    @error_log = ErrorLog.find(params[:id])
  end
end
