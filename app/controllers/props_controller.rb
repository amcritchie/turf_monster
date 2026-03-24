class PropsController < ApplicationController
  skip_before_action :require_authentication

  def show
    @prop = Prop.find_by(slug: params[:id])
    return redirect_to root_path, alert: "Prop not found" unless @prop
    @picks = @prop.picks.includes(entry: :user)
  end
end
