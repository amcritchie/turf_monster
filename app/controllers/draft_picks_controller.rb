class DraftPicksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:beacon]

  def show
    draft = DraftPick.load_draft(current_user, contest)
    if draft
      render json: { picks: draft.picks, updated_at: draft.updated_at.iso8601(3) }
    else
      render json: {}
    end
  end

  def update
    unless contest.open?
      return render json: { error: "Contest is not open" }, status: :unprocessable_entity
    end

    if contest.entries.exists?(user: current_user)
      return render json: { error: "Already entered" }, status: :unprocessable_entity
    end

    draft = DraftPick.save_draft(current_user, contest, picks_params)
    if draft
      render json: { picks: draft.picks, updated_at: draft.updated_at.iso8601(3) }
    else
      render json: {}
    end
  end

  def beacon
    return head :unauthorized unless logged_in?
    return head :unprocessable_entity unless contest.open?
    return head :unprocessable_entity if contest.entries.exists?(user: current_user)

    DraftPick.save_draft(current_user, contest, picks_params)
    head :ok
  end

  private

  def contest
    @contest ||= Contest.find(params[:contest_id])
  end

  def picks_params
    params.fetch(:picks, {}).permit!.to_h
  end
end
