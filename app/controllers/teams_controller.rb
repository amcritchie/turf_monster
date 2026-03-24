class TeamsController < ApplicationController
  skip_before_action :require_authentication

  def index
    @teams = Team.order(:name)
  end

  def show
    @team = Team.find_by(slug: params[:id])
    return redirect_to teams_path, alert: "Team not found" unless @team
  end
end
