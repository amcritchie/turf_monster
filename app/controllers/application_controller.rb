class ApplicationController < ActionController::Base
  include Studio::ErrorHandling

  allow_browser versions: :modern
end
