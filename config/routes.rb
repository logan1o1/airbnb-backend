Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Devise routes (no HTML sessions/registrations, JWT only)
  devise_for :users, skip: %i[sessions registrations passwords confirmations unlocks]

  # Authentication endpoints for JWT
  post "auth/login", to: "auth#login"
  post "auth/logout", to: "auth#logout"

  # TODO: add API routes for listings, bookings, etc.
end
