Studio.configure do |config|
  config.app_name = "Turf Monster"
  config.welcome_message = ->(user) { "Welcome to Turf Monster, #{user.display_name}!" }
  config.registration_params = [:email, :password, :password_confirmation]
  config.configure_new_user = ->(user) { user.balance_cents = 0 }
  config.configure_sso_user = ->(user) { user.balance_cents = 0 }
end
