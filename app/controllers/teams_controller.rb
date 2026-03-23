class TeamsController < ApplicationController
  skip_before_action :require_authentication

  def index
    @teams = Team.order(:name)
  end
end
