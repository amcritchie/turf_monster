Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  root "contests#index"

  get "turf-totals-v1", to: "pages#turf_totals_v1", as: :turf_totals_v1

  # Public faucet page
  get  "faucet", to: "faucet#show", as: :faucet
  post "faucet", to: "faucet#claim"

  Studio.routes(self)

  # Solana wallet auth
  get  "auth/solana/nonce",  to: "solana_sessions#nonce"
  post "auth/solana/verify", to: "solana_sessions#verify"

  # Account management
  resource :account, only: [:show, :update] do
    get :complete_profile
    post :save_profile
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

  resources :contests, only: [:index, :show, :new, :create] do
    collection do
      get :my
    end
    member do
      post :toggle_selection
      post :enter
      post :prepare_entry
      post :confirm_onchain_entry
      post :clear_picks
      post :grade
      post :fill
      post :lock
      post :jump
      post :simulate_game
      post :simulate_batch
      post :reset
      post :create_onchain
      post :payout_entry
    end
  end

  resources :teams, only: [:index, :show]
  resources :games, only: [:index]

  resource :wallet, only: [:show] do
    post :deposit
    post :withdraw
    post :faucet
    post :airdrop
    get :sync
  end

  post "add_funds", to: "users#add_funds"

  # Admin: Mint USDC (devnet) + balance check
  post "admin/mint_usdc", to: "admin#mint_usdc", as: :admin_mint_usdc
  get "admin/usdc_balance", to: "admin#usdc_balance", as: :admin_usdc_balance

  # Admin: Contests
  get "admin/contests", to: "contests#admin_index", as: :admin_contests

  # Admin: Transaction Logs
  get "admin/transactions", to: "transaction_logs#index", as: :admin_transactions
  get "admin/transactions/:slug", to: "transaction_logs#show", as: :admin_transaction
  post "admin/transactions/:slug/approve", to: "transaction_logs#approve", as: :admin_transaction_approve
  post "admin/transactions/:slug/deny", to: "transaction_logs#deny", as: :admin_transaction_deny

  # Geo check (public — used by hold-to-confirm validation)
  get "geo/check", to: "geo_settings#check", as: :geo_check

  # Admin: Geo Settings
  get "admin/geo", to: "geo_settings#edit", as: :admin_geo
  patch "admin/geo", to: "geo_settings#update", as: :admin_geo_update
  post "admin/geo/toggle", to: "geo_settings#toggle_override", as: :admin_geo_toggle
end
