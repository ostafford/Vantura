require "sidekiq/web"

Rails.application.routes.draw do
  devise_for :users

  # Secure Sidekiq Web UI - only accessible to admin users
  authenticate :user, ->(user) { user.admin? } do
    mount Sidekiq::Web => "/sidekiq"
  end

  root "dashboard#index"

  # Onboarding
  get "/onboarding/connect_up_bank", to: "onboarding#connect_up_bank", as: :onboarding_connect_up_bank
  post "/onboarding/connect_up_bank", to: "onboarding#create_connection", as: :onboarding_create_connection
  get "/onboarding/sync_progress", to: "onboarding#sync_progress", as: :onboarding_sync_progress
  post "/onboarding/skip_connection", to: "onboarding#skip_connection", as: :onboarding_skip_connection

  # Webhooks
  post "/webhooks/up", to: "webhooks#up"

  # Dashboard
  get "/dashboard", to: "dashboard#index"
  post "/sync", to: "dashboard#sync"

  # Transactions
  resources :transactions, only: [ :index, :show, :update ]

  # Calendar
  get "/calendar", to: "calendar#index"

  # Projects
  resources :projects do
    resources :project_expenses
  end

  # Settings
  get "/settings", to: "settings#index"
  patch "/settings", to: "settings#update"

  # Goals
  resources :goals, only: [ :index, :create, :update, :destroy ]

  # Planned Transactions
  resources :planned_transactions

  # Feedback
  resources :feedback_items, only: [ :create ]

  # Health checks
  get "up" => "rails/health#show", as: :rails_health_check
  get "health/full" => "health#full", as: :full_health_check
end
