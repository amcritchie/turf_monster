Rails.application.config.moonpay = {
  api_key: ENV["MOONPAY_API_KEY"],
  secret_key: ENV["MOONPAY_SECRET_KEY"],
  webhook_key: ENV["MOONPAY_WEBHOOK_KEY"],
  base_url: ENV.fetch("MOONPAY_BASE_URL", "https://buy-sandbox.moonpay.com")
}
