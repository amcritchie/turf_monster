class HelpController < ApplicationController
  skip_before_action :require_authentication
  skip_before_action :require_profile_completion, raise: false

  def index; end
  def how_to_play; end
  def phantom; end
  def glossary; end
end
