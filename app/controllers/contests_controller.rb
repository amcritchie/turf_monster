class ContestsController < ApplicationController
  skip_before_action :require_authentication, only: [:index, :show, :my]
  before_action :set_contest, only: [:show, :toggle_pick, :toggle_selection, :enter, :clear_picks, :grade, :fill, :lock, :jump, :simulate_game, :reset, :rank_matchups, :update_rankings]
  before_action :require_admin, only: [:grade, :fill, :lock, :jump, :simulate_game, :reset, :rank_matchups, :update_rankings]

  def index
    @contest = Contest.order(created_at: :desc).first
    @entries = @contest&.entries&.where(status: [:active, :complete])&.includes(:user) || []

    if @contest&.turf_totals?
      @matchups = @contest.contest_matchups.includes(:team, :opponent_team, :game).order(rank: :desc)
      @entries = @entries.includes(selections: { contest_matchup: :team })
      if logged_in?
        @cart_entry = @contest.entries.cart.find_by(user: current_user)
      end
    else
      @props = @contest&.props&.includes(:team, :opponent_team, :game) || []
      @entries = @entries.includes(picks: { prop: :team })
      if logged_in? && @contest
        @cart_entry = @contest.entries.cart.find_by(user: current_user)
      end
    end
  end

  def my
    @contests = Contest.where(status: [:open, :locked, :settled]).order(created_at: :desc)
    if logged_in?
      @my_entries = current_user.entries.where(status: [:active, :complete]).includes(:contest, picks: { prop: [:team, :opponent_team] }).group_by(&:contest_id)
    else
      @my_entries = {}
    end
  end

  def show
    if @contest.turf_totals?
      @matchups = @contest.contest_matchups.ranked.includes(:team, :opponent_team, :game)
      @entries = @contest.entries.where(status: [:active, :complete]).includes(:user, selections: { contest_matchup: :team }).order(score: :desc)
    else
      @props = @contest.props.includes(:team, :opponent_team, :game)
      @entries = @contest.entries.where(status: [:active, :complete]).includes(:user, picks: { prop: :team }).order(score: :desc)
    end
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
      active_count = @contest.entries.where(status: [:active, :complete]).count
      raise "Contest is full" if @contest.max_entries && active_count >= @contest.max_entries

      entry.confirm!

      respond_to do |format|
        format.html { redirect_to @contest, notice: "#{current_user.display_name} entered the contest!" }
        format.json { render json: { success: true, redirect: contest_path(@contest) } }
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

  def toggle_selection
    unless @contest.open?
      return render json: { error: "Contest is not open" }, status: :unprocessable_entity
    end

    matchup = @contest.contest_matchups.find_by(id: params[:matchup_id])
    return render json: { error: "Matchup not found" }, status: :not_found unless matchup

    entry = @contest.entries.find_or_create_by!(user: current_user, status: :cart)

    rescue_and_log(target: entry, parent: @contest) do
      selections_hash = entry.toggle_selection!(matchup)

      if selections_hash.nil?
        render json: { selections: {}, selection_count: 0 }
      else
        render json: { selections: selections_hash, selection_count: selections_hash.size }
      end
    end
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def simulate_game
    rescue_and_log(target: @contest) do
      game = @contest.simulate_next_game!
      redirect_to @contest, notice: "Simulated #{game.home_team.name} vs #{game.away_team.name}: #{game.home_score}-#{game.away_score}"
    end
  rescue StandardError => e
    redirect_to @contest || root_path, alert: e.message
  end

  def rank_matchups
    @matchups = @contest.contest_matchups.ranked.includes(:team, :opponent_team, :game)
  end

  def update_rankings
    rescue_and_log(target: @contest) do
      if params[:matchup_ids].present?
        params[:matchup_ids].each_with_index do |id, index|
          matchup = @contest.contest_matchups.find_by(id: id)
          next unless matchup
          rank = index + 1
          matchup.update!(rank: rank, multiplier: (Math.sqrt(rank) * 0.5).round(1))
        end
      end
      redirect_to rank_matchups_contest_path(@contest), notice: "Rankings saved! Multipliers generated."
    end
  rescue StandardError => e
    redirect_to @contest || root_path, alert: e.message
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

  def fill
    rescue_and_log(target: @contest) do
      @contest.fill!(users: User.where(email: [
        "alex@mcritchie.studio", "mason@mcritchie.studio",
        "mack@mcritchie.studio", "turf@mcritchie.studio"
      ]))
      redirect_to @contest, notice: "Contest filled with #{@contest.entries.where(status: [:active, :complete]).count} entries!"
    end
  rescue StandardError => e
    redirect_to @contest || root_path, alert: e.message
  end

  def lock
    rescue_and_log(target: @contest) do
      @contest.update!(status: :locked)
      redirect_to @contest, notice: "Contest locked!"
    end
  rescue StandardError => e
    redirect_to @contest || root_path, alert: e.message
  end

  def jump
    rescue_and_log(target: @contest) do
      @contest.jump!
      redirect_to @contest, notice: "Contest jumped! Results simulated and settled."
    end
  rescue StandardError => e
    redirect_to @contest || root_path, alert: e.message
  end

  def reset
    rescue_and_log(target: @contest) do
      @contest.reset!
      redirect_to root_path, notice: "Contest reset!"
    end
  rescue StandardError => e
    redirect_to root_path, alert: e.message
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
