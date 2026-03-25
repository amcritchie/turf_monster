Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  root "contests#index"

  Studio.routes(self)

  # Wallet auth (SIWE)
  get  "auth/wallet/nonce",  to: "wallet_sessions#nonce"
  post "auth/wallet/verify", to: "wallet_sessions#verify"

  # Account management
  resource :account, only: [:show, :update] do
    post :link_wallet
    post :unlink_google
    post :change_password
  end

  resources :contests, only: [:index, :show] do
    member do
      post :toggle_pick
      post :enter
      post :clear_picks
      post :grade
    end
  end

  resources :props, only: [:show]
  resources :teams, only: [:index, :show]
  resources :games, only: [:index]

  post "add_funds", to: "users#add_funds"
end
