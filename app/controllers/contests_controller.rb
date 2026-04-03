class ContestsController < ApplicationController
  skip_before_action :require_authentication, only: [:index, :show, :my]
  before_action :set_contest, only: [:show, :toggle_selection, :enter, :clear_picks, :grade, :fill, :lock, :jump, :simulate_game, :simulate_batch, :reset, :create_onchain, :payout_entry]
  before_action :require_admin, only: [:new, :create, :admin_index, :grade, :fill, :lock, :jump, :simulate_game, :simulate_batch, :reset, :create_onchain, :payout_entry]
  before_action :require_geo_allowed, only: [:toggle_selection, :enter]

  def index
    @contests = Contest.where(status: [:open, :locked, :settled]).order(created_at: :asc)
    @contest = @contests.first
    return unless @contest

    @entries = @contest.entries.where(status: [:active, :complete]).includes(:user, selections: { slate_matchup: :team })
    @matchups = @contest.matchups.includes(:team, :opponent_team, :game).order(:rank)
    @cart_entry = @contest.entries.cart.find_by(user: current_user) if logged_in?
  end

  def admin_index
    @contests = Contest.order(created_at: :desc).includes(:slate)
  end

  def my
    @contests = Contest.where(status: [:open, :locked, :settled]).order(created_at: :desc)
    if logged_in?
      @my_entries = current_user.entries.where(status: [:active, :complete]).includes(:contest, selections: { slate_matchup: [:team, :opponent_team] }).group_by(&:contest_id)
    else
      @my_entries = {}
    end
  end

  def new
    @contest = Contest.new(contest_type: "small")
  end

  def create
    @contest = Contest.new(contest_params)
    config = @contest.format_config
    @contest.entry_fee_cents = config[:entry_fee_cents]
    @contest.max_entries = config[:max_entries]
    @contest.status = :open

    rescue_and_log(target: @contest) do
      @contest.save!
      redirect_to @contest, notice: "Contest created! Submit onchain transaction from the contest page."
    end
  rescue StandardError => e
    render :new, status: :unprocessable_entity
  end

  def create_onchain
    rescue_and_log(target: @contest) do
      raise "Already onchain" if @contest.onchain?
      @contest.create_onchain!

      invalidate_usdc_cache if logged_in?

      render json: { success: true, tx: @contest.onchain_tx_signature, pda: @contest.onchain_contest_id }
    end
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  def payout_entry
    entry = @contest.entries.find_by(id: params[:entry_id])
    return render json: { success: false, error: "Entry not found" }, status: :not_found unless entry

    rescue_and_log(target: entry, parent: @contest) do
      raise "Contest not settled" unless @contest.settled?
      raise "No payout for this entry" if entry.payout_cents.to_i == 0
      raise "Already paid" if entry.payout_tx_signature.present?
      raise "User has no Solana wallet" unless entry.user.solana_connected?

      vault = Solana::Vault.new
      amount = Solana::Config.dollars_to_lamports(entry.payout_cents / 100.0)
      result = vault.transfer_spl(entry.user.solana_address, amount, mint: Solana::Config::USDC_MINT)

      entry.update!(payout_tx_signature: result[:signature])
      invalidate_usdc_cache

      render json: { success: true, tx: result[:signature], entry_id: entry.id }
    end
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  def show
    @contests = Contest.where(status: [:open, :locked, :settled]).order(created_at: :asc)
    @matchups = @contest.matchups.ranked.includes(:team, :opponent_team, :game)
    @entries = @contest.entries.where(status: [:active, :complete]).includes(:user, selections: { slate_matchup: :team }).order(score: :desc)
    @cart_entry = @contest.entries.cart.find_by(user: current_user) if logged_in?

    if logged_in?
      group_slates = Slate.where.not(name: "Default").where.not(starts_at: nil).order(:starts_at)
      @slate_progress = current_user.slate_progress(group_slates)
    end

    if @contest.onchain?
      begin
        @onchain_contest = Solana::Vault.new.read_contest(@contest.slug)
      rescue => e
        Rails.logger.warn "Failed to read onchain contest: #{e.message}"
      end
    end
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
        format.json {
          render json: {
            success: true,
            redirect: contest_path(@contest),
            tx_signature: entry.onchain_tx_signature
          }
        }
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

    matchup = @contest.matchups.find_by(id: params[:matchup_id])
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

  def grade
    rescue_and_log(target: @contest) do
      @contest.grade!

      respond_to do |format|
        format.html { redirect_to @contest, notice: "Contest graded and settled!" }
        format.json {
          render json: {
            success: true,
            redirect: contest_path(@contest),
            tx_signature: @contest.onchain_tx_signature
          }
        }
      end
    end
  rescue StandardError => e
    respond_to do |format|
      format.html { redirect_to @contest || root_path, alert: e.message }
      format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
    end
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

  def simulate_batch
    count = params[:count].to_i
    count = 5 if count <= 0

    rescue_and_log(target: @contest) do
      simulated = @contest.simulate_games!(count)
      redirect_to @contest, notice: "Simulated #{simulated} game(s)."
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

  def contest_params
    params.require(:contest).permit(:name, :slate_id, :contest_type)
  end
end
