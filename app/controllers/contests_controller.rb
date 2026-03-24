class ContestsController < ApplicationController
  skip_before_action :require_authentication, only: [:index, :show]
  before_action :set_contest, only: [:show, :toggle_pick, :enter, :clear_picks, :grade]

  def index
    @contest = Contest.order(created_at: :desc).first
    @props = @contest&.props&.includes(:team, :opponent_team, :game) || []
    @entries = @contest&.entries&.where(status: [:active, :complete])&.includes(:user, picks: :prop) || []

    if logged_in? && @contest
      @cart_entry = @contest.entries.cart.find_by(user: current_user)
    end
  end

  def show
    @props = @contest.props.includes(:team, :opponent_team, :game)
    @entries = @contest.entries.where(status: [:active, :complete]).includes(:user, picks: :prop).order(score: :desc)
  end

  def toggle_pick
    unless @contest.open?
      return render json: { error: "Contest is not open" }, status: :unprocessable_entity
    end

    prop = @contest.props.find_by(id: params[:prop_id])
    return render json: { error: "Prop not found" }, status: :not_found unless prop

    selection = params[:selection]
    entry = @contest.entries.find_or_create_by!(user: current_user, status: :cart)

    rescue_and_log(target: entry, parent: @contest) do
      picks_hash = entry.toggle_pick!(prop, selection)

      if picks_hash.nil?
        render json: { picks: {}, pick_count: 0 }
      else
        render json: { picks: picks_hash, pick_count: picks_hash.size }
      end
    end
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def enter
    entry = @contest.entries.cart.find_by(user: current_user)
    return redirect_to root_path, alert: "No cart entry found" unless entry

    rescue_and_log(target: entry, parent: @contest) do
      entry.confirm!

      respond_to do |format|
        format.html { redirect_to root_path, notice: "#{current_user.display_name} entered the contest!" }
        format.json { render json: { success: true, redirect: root_path } }
      end
    end
  rescue StandardError => e
    respond_to do |format|
      format.html { redirect_to root_path, alert: e.message }
      format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
    end
  end

  def clear_picks
    entry = @contest.entries.cart.find_by(user: current_user)

    rescue_and_log(target: entry, parent: @contest) do
      if entry
        entry.update!(status: :abandoned)
      end

      respond_to do |format|
        format.html { redirect_to root_path, notice: "Picks cleared" }
        format.json { render json: { success: true } }
      end
    end
  rescue StandardError => e
    respond_to do |format|
      format.html { redirect_to root_path, alert: e.message }
      format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
    end
  end

  def grade
    rescue_and_log(target: @contest) do
      if params[:results].present?
        params[:results].each do |prop_id, value|
          next if value.blank?
          prop = Prop.find_by(id: prop_id)
          next unless prop
          prop.update!(result_value: value.to_f)
        end
      end

      @contest.grade!
      redirect_to @contest, notice: "Contest graded and settled!"
    end
  rescue StandardError => e
    redirect_to @contest || root_path, alert: e.message
  end

  private

  def set_contest
    @contest = Contest.find_by(slug: params[:id])
    return if @contest

    respond_to do |format|
      format.html { redirect_to root_path, alert: "Contest not found" }
      format.json { render json: { error: "Contest not found" }, status: :not_found }
    end
  end
end
