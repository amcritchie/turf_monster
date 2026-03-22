class ContestsController < ApplicationController
  skip_before_action :require_authentication, only: [:index, :show]

  def index
    @contest = Contest.order(created_at: :desc).first
    @props = @contest&.props || []
    @entries = @contest&.entries&.includes(:user, picks: :prop) || []
  end

  def show
    @contest = Contest.find(params[:id])
    @props = @contest.props
    @entries = @contest.entries.includes(:user, picks: :prop).order(score: :desc)
  end

  def enter
    @contest = Contest.find(params[:id])
    @contest.enter!(current_user, params[:picks] || {})

    respond_to do |format|
      format.html { redirect_to root_path, notice: "#{current_user.display_name} entered the contest!" }
      format.json { render json: { success: true, redirect: root_path } }
    end
  rescue => e
    respond_to do |format|
      format.html { redirect_to root_path, alert: e.message }
      format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
    end
  end

  def grade
    @contest = Contest.find(params[:id])

    if params[:results].present?
      params[:results].each do |prop_id, value|
        next if value.blank?
        Prop.find(prop_id).update!(result_value: value.to_f)
      end
    end

    @contest.grade!
    redirect_to @contest, notice: "Contest graded and settled!"
  rescue => e
    redirect_to @contest, alert: e.message
  end
end
