class GamesController < ApplicationController
  skip_before_action :require_authentication

  def index
    @games = Game.includes(:home_team, :away_team).order(:kickoff_at)
  end
end
