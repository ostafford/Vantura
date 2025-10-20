Rails.application.routes.draw do
  # Dashboard
  root "dashboard#index"
  post "sync", to: "dashboard#sync", as: :sync

  # Calendar
  get "calendar", to: "calendar#index"
  get "calendar/:year/:month", to: "calendar#index", as: :calendar_month

  # Transactions (for hypothetical transactions)
  resources :transactions, only: [ :create, :destroy ]
  get "transactions/all", to: "transactions#all", as: :transactions_all
  get "transactions/all/:year/:month", to: "transactions#all", as: :transactions_all_month
  get "transactions/expenses", to: "transactions#expenses", as: :transactions_expenses
  get "transactions/expenses/:year/:month", to: "transactions#expenses", as: :transactions_expenses_month
  get "transactions/income", to: "transactions#income", as: :transactions_income
  get "transactions/income/:year/:month", to: "transactions#income", as: :transactions_income_month

  # Trends
  get "trends", to: "trends#index", as: :trends

  # Recurring transactions
  resources :recurring_transactions, only: [ :index, :create, :destroy ] do
    member do
      post :toggle_active
    end
  end

  # Health check and PWA routes...
  get "up" => "rails/health#show", as: :rails_health_check
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
end
