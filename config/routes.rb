Rails.application.routes.draw do
  # Sidekiq Web UI removed - using Solid Queue (no web UI needed)
  # Solid Queue jobs can be monitored via database queries or custom admin panel

  root "dashboard#index"

  devise_for :users

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
  resources :transactions, only: [ :index, :show, :update ] do
    collection do
      get :export
    end
  end

  # Calendar
  get "/calendar", to: "calendar#index"
  get "/calendar/export", to: "calendar#export", as: :calendar_export

  # Projects
  resources :projects do
    resources :project_expenses do
      resources :expense_contributions, only: [] do
        member do
          patch :mark_paid
        end
      end
    end
  end

  # Settings
  get "/settings", to: "settings#index", as: :settings
  patch "/settings", to: "settings#update"
  patch "/settings/password", to: "settings#update_password", as: :settings_password
  patch "/settings/up_bank_token", to: "settings#update_up_bank_token", as: :settings_up_bank_token
  post "/settings/sync_now", to: "settings#sync_now", as: :settings_sync_now
  delete "/settings/disconnect_bank", to: "settings#disconnect_bank", as: :settings_disconnect_bank
  delete "/settings/account", to: "settings#destroy_account", as: :settings_account

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
