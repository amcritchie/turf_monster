Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  root "contests#index"

  get "turf-totals-v1", to: "pages#turf_totals_v1", as: :turf_totals_v1

  Studio.routes(self)

  # Solana wallet auth
  get  "auth/solana/nonce",  to: "solana_sessions#nonce"
  post "auth/solana/verify", to: "solana_sessions#verify"

  # Account management
  resource :account, only: [:show, :update] do
    post :link_solana
    post :unlink_google
    post :change_password
  end

  resources :slates, only: [:index, :show] do
    member do
      patch :update_rankings
      patch :update_multipliers
      patch :update_formula
    end
    collection do
      get :formula_report
      get :admin_formula
      patch :update_admin_formula
    end
  end

  resources :contests, only: [:index, :show] do
    collection do
      get :my
    end
    member do
      post :toggle_selection
      post :enter
      post :clear_picks
      post :grade
      post :fill
      post :lock
      post :jump
      post :simulate_game
      post :reset
    end
  end

  resources :teams, only: [:index, :show]
  resources :games, only: [:index]

  resource :wallet, only: [:show] do
    post :deposit
    post :withdraw
    post :faucet
    get :sync
  end

  post "add_funds", to: "users#add_funds"
end
