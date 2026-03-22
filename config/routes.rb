Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  root "contests#index"

  resources :contests, only: [:index, :show] do
    member do
      post :enter
      post :grade
    end
  end

  resources :props, only: [:show]

  resources :users, only: [] do
    member do
      post :add_funds
    end
  end
end
