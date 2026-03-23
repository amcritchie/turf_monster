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
    existing_pick = entry.picks.find_by(prop: prop)

    if existing_pick
      if existing_pick.selection == selection
        existing_pick.destroy!
      else
        existing_pick.update!(selection: selection)
      end
    elsif entry.picks.count < 3
      entry.picks.create!(prop: prop, selection: selection)
    else
      return render json: { error: "Maximum 3 picks" }, status: :unprocessable_entity
    end

    entry.reload
    if entry.picks.empty?
      entry.destroy!
      return render json: { picks: {}, pick_count: 0 }
    end

    picks_hash = entry.picks.each_with_object({}) { |p, h| h[p.prop_id.to_s] = p.selection }
    render json: { picks: picks_hash, pick_count: entry.picks.count }
  rescue => e
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
