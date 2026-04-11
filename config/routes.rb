Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Devise routes (no HTML sessions/registrations, JWT only)
  devise_for :users, skip: %i[sessions registrations passwords confirmations unlocks]

  # Authentication endpoints for JWT
  post "auth/signup", to: "auth#signup"
  post "auth/login", to: "auth#login"
  post "auth/logout", to: "auth#logout"

  # Resources
  resources :listings, only: %i[index show create update destroy] do
    collection do
      get :my_listings
    end
  end
  resources :bookings, only: %i[index show create]
  resources :payments, only: [ :create ]

  # Razorpay webhook (no authentication required)
  post "webhooks/razorpay", to: "payments#verify"
end
