Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  root "contests#index"

  get  "login",  to: "sessions#new"
  post "login",  to: "sessions#create"
  get  "logout", to: "sessions#destroy"

  get  "signup", to: "registrations#new"
  post "signup", to: "registrations#create"

  get "auth/:provider/callback", to: "omniauth_callbacks#create"
  get "auth/failure", to: "omniauth_callbacks#failure"

  resources :contests, only: [:index, :show] do
    member do
      post :toggle_pick
      post :enter
      post :grade
    end
  end

  resources :props, only: [:show]
  resources :error_logs, only: [:index, :show]

  post "add_funds", to: "users#add_funds"
end
