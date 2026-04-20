class PlayersController < ApplicationController
  skip_before_action :require_authentication

  def index
    @players = Player.includes(:team).order(:name)
  end
end
