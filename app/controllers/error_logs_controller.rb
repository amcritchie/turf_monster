class ErrorLogsController < ApplicationController
  skip_before_action :require_authentication

  def index
    @error_logs = ErrorLog.order(created_at: :desc).limit(100)
  end

  def show
    @error_log = ErrorLog.find_by(slug: params[:id])
    return redirect_to error_logs_path, alert: "Error log not found" unless @error_log
  end
end
