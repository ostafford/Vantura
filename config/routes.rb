require "sidekiq/web"

Rails.application.routes.draw do
  devise_for :users

  # Sidekiq web UI (protect with authentication in production)
  mount Sidekiq::Web => "/sidekiq" if Rails.env.development?

  root "dashboard#index"

  # Webhooks
  post "/webhooks/up", to: "webhooks#up"

  # Dashboard
  get "/dashboard", to: "dashboard#index"
  post "/sync", to: "dashboard#sync"

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
