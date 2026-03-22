class PropsController < ApplicationController
  def show
    @prop = Prop.find(params[:id])
    @picks = @prop.picks.includes(entry: :user)
  end
end
