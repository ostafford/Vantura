Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Devise routes with custom controllers
  devise_for :users, controllers: {
    registrations: 'users/registrations',
    sessions: 'users/sessions'
  }

  # Public root
  root 'home#index'

  # Protected routes
  authenticate :user do
    root 'dashboard#index', as: :authenticated_root
    
    # Explicit dashboard route for redirects
    get 'dashboard', to: 'dashboard#index', as: :dashboard

    resources :accounts, only: [:index, :show] do
      resources :transactions, only: [:index]
    end

    resources :transactions, only: [:index, :show] do
      collection do
        get :search
      end
    end

    resources :budgets do
      member do
        post :toggle_active
      end
    end

    resources :investment_goals do
      member do
        post :toggle_active
      end
    end

    resource :settings, only: [:show, :update] do
      collection do
        post :sync_now
      end
    end
  end
end
