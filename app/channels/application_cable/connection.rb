module ApplicationCable
  class Connection < ActionCable::Connection::Base
    include Studio::CableAuth
  end
end
