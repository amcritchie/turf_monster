class ContestsController < ApplicationController
  skip_before_action :require_authentication, only: [:index, :show]

  def index
    @contest = Contest.order(created_at: :desc).first
    @props = @contest&.props || []
    @entries = @contest&.entries&.where(status: [:active, :complete])&.includes(:user, picks: :prop) || []

    if logged_in? && @contest
      @cart_entry = @contest.entries.cart.find_by(user: current_user)
    end
  end

  def show
    @contest = Contest.find(params[:id])
    @props = @contest.props
    @entries = @contest.entries.where(status: [:active, :complete]).includes(:user, picks: :prop).order(score: :desc)
  end

  def toggle_pick
    @contest = Contest.find(params[:id])

    unless @contest.open?
      return render json: { error: "Contest is not open" }, status: :unprocessable_entity
    end

    if @contest.entries.where(user: current_user, status: [:active, :complete]).exists?
      return render json: { error: "Already entered" }, status: :unprocessable_entity
    end

    prop = @contest.props.find(params[:prop_id])
    selection = params[:selection]

    entry = @contest.entries.find_or_create_by!(user: current_user, status: :cart)
    picks_hash = entry.toggle_pick!(prop, selection)

    if picks_hash.nil?
      render json: { picks: {}, pick_count: 0 }
    else
      render json: { picks: picks_hash, pick_count: picks_hash.size }
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Record not found" }, status: :not_found
  rescue ActiveRecord::RecordInvalid, RuntimeError => e
    ErrorLog.capture!(e, target: entry, parent: @contest)
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def enter
    @contest = Contest.find(params[:id])
    entry = @contest.entries.cart.find_by!(user: current_user)
    entry.confirm!

    respond_to do |format|
      format.html { redirect_to root_path, notice: "#{current_user.display_name} entered the contest!" }
      format.json { render json: { success: true, redirect: root_path } }
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to root_path, alert: "No cart entry found" }
      format.json { render json: { success: false, error: "No cart entry found" }, status: :unprocessable_entity }
    end
  rescue ActiveRecord::RecordInvalid, RuntimeError => e
    ErrorLog.capture!(e, target: entry, parent: @contest)
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
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Contest or prop not found"
  rescue ActiveRecord::RecordInvalid, RuntimeError => e
    ErrorLog.capture!(e, target: @contest)
    redirect_to @contest, alert: e.message
  end
end
