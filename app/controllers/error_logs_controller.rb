class ErrorLogsController < ApplicationController
  skip_before_action :require_authentication

  def index
    @error_logs = ErrorLog.order(created_at: :desc)
    if params[:q].present?
      @error_logs = @error_logs.where("message ILIKE :q OR target_name ILIKE :q OR parent_name ILIKE :q OR target_type ILIKE :q", q: "%#{params[:q]}%")
    end
    @error_logs = @error_logs.limit(100)
  end

  def show
    @error_log = ErrorLog.find_by(slug: params[:id])
    return redirect_to error_logs_path, alert: "Error log not found" unless @error_log
  end
end
