require "sidekiq/web"

Rails.application.routes.draw do
  devise_for :users

  # Secure Sidekiq Web UI - only accessible to admin users
  authenticate :user, ->(user) { user.admin? } do
    mount Sidekiq::Web => "/sidekiq"
  end

  root "dashboard#index"

  # Webhooks
  post "/webhooks/up", to: "webhooks#up"

  # Dashboard
  get "/dashboard", to: "dashboard#index"
  post "/sync", to: "dashboard#sync"

  # Health checks
  get "up" => "rails/health#show", as: :rails_health_check
  get "health/full" => "health#full", as: :full_health_check
end
