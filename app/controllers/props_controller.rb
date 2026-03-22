class PropsController < ApplicationController
  skip_before_action :require_authentication

  def show
    @prop = Prop.find(params[:id])
    @picks = @prop.picks.includes(entry: :user)
  end
end
