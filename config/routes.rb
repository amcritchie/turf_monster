Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  root "contests#index"

  Studio.routes(self)

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
