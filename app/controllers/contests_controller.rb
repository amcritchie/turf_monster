class ContestsController < ApplicationController
  def index
    @contest = Contest.order(created_at: :desc).first
    @users = User.all
    @props = @contest&.props || []
    @entries = @contest&.entries&.includes(:user, picks: :prop) || []
  end

  def show
    @contest = Contest.find(params[:id])
    @users = User.all
    @props = @contest.props
    @entries = @contest.entries.includes(:user, picks: :prop).order(score: :desc)
  end

  def enter
    @contest = Contest.find(params[:id])
    user = User.find(params[:user_id])
    @contest.enter!(user, params[:picks] || {})
    redirect_to @contest, notice: "#{user.name} entered the contest!"
  rescue => e
    redirect_to @contest, alert: e.message
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
