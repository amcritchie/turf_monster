Rails.application.config.session_store :cookie_store,
  key: "_studio_session",
  domain: (Rails.env.production? ? ".mcritchie.studio" : :all)
