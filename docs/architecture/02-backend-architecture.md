# Backend Architecture
## Rails Application Structure & Implementation

**Document Version:** 1.0  
**Last Updated:** December 2025  
**Related:** [Architecture Overview](./01-architecture-overview.md)

---

## Table of Contents

1. [Rails Application Structure](#rails-application-structure)
2. [Database Schema](#database-schema)
3. [Models & Relationships](#models--relationships)
4. [API Integration Layer](#api-integration-layer)
5. [Background Jobs](#background-jobs)
6. [Services & Business Logic](#services--business-logic)
7. [Controllers & Routes](#controllers--routes)
8. [Error Handling](#error-handling)

---

## Rails Application Structure

### Directory Organization

```
app/
├── controllers/
│   ├── application_controller.rb
│   ├── dashboard_controller.rb
│   ├── accounts_controller.rb
│   ├── transactions_controller.rb
│   ├── budgets_controller.rb
│   ├── investment_goals_controller.rb
│   └── settings_controller.rb
├── models/
│   ├── user.rb
│   ├── account.rb
│   ├── transaction.rb
│   ├── category.rb
│   ├── tag.rb
│   ├── budget.rb
│   └── investment_goal.rb
├── services/
│   ├── up_api/
│   │   ├── client.rb
│   │   ├── accounts_sync.rb
│   │   ├── transactions_sync.rb
│   │   └── categories_sync.rb
│   ├── budget_calculator.rb
│   └── investment_tracker.rb
├── jobs/
│   ├── sync_accounts_job.rb
│   ├── sync_transactions_job.rb
│   └── calculate_budgets_job.rb
├── mailers/
│   └── budget_alert_mailer.rb
└── helpers/
    ├── transactions_helper.rb
    └── budgets_helper.rb

config/
├── routes.rb
├── database.yml
├── credentials.yml.enc
└── initializers/
    ├── devise.rb
    └── solid_queue.rb

db/
├── migrate/
└── schema.rb
```

### Key Rails Conventions

- **Controllers:** Handle HTTP requests, minimal logic
- **Models:** Database interactions, validations, associations
- **Services:** Complex business logic, external API calls
- **Jobs:** Background processing, async operations
- **Mailers:** Email notifications
- **Helpers:** View helpers (minimal use with Hotwire)

---

## Database Schema

### Core Tables

#### users

```ruby
create_table "users" do |t|
  t.string "email", default: "", null: false
  t.string "encrypted_password", default: "", null: false
  t.string "reset_password_token"
  t.datetime "reset_password_sent_at"
  t.datetime "remember_created_at"
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  # Rails 8.1.1+ encryption - single column
  t.text "up_pat_ciphertext"  # Encrypted PAT storage
  t.datetime "last_synced_at"
  t.index ["email"], name: "index_users_on_email", unique: true
  t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
end
```

**Fields:**
- Standard Devise fields (email, password, etc.)
- `up_pat_ciphertext`: Encrypted Up Bank PAT (Rails 8.1.1+ stores IV/salt/metadata inside ciphertext JSON)
- `last_synced_at`: Timestamp of last successful sync

#### accounts

```ruby
create_table "accounts" do |t|
  t.bigint "user_id", null: false
  t.string "up_id", null: false  # Up API account ID
  t.string "account_type", null: false  # TRANSACTIONAL, SAVER, HOME_LOAN
  t.string "ownership_type", null: false  # INDIVIDUAL, JOINT
  t.string "display_name"
  t.decimal "balance", precision: 10, scale: 2, null: false
  t.string "currency_code", default: "AUD"
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.datetime "up_created_at"  # Created timestamp from Up API
  t.index ["user_id"], name: "index_accounts_on_user_id"
  t.index ["up_id"], name: "index_accounts_on_up_id", unique: true
  t.index ["user_id", "account_type"], name: "index_accounts_on_user_and_type"
end
```

**Fields:**
- `up_id`: Unique identifier from Up API
- `account_type`: TRANSACTIONAL, SAVER, or HOME_LOAN
- `ownership_type`: INDIVIDUAL or JOINT
- `balance`: Current account balance
- `currency_code`: Currency (default AUD)

#### transactions

```ruby
create_table "transactions" do |t|
  t.bigint "user_id", null: false
  t.bigint "account_id", null: false
  t.string "up_id", null: false  # Up API transaction ID
  t.string "status", null: false  # HELD or SETTLED
  t.string "raw_text"
  t.text "description"
  t.string "message"
  t.boolean "hold_info_is_cover", default: false
  t.decimal "amount", precision: 10, scale: 2, null: false
  t.string "currency_code", default: "AUD"
  t.string "foreign_amount"
  t.string "foreign_currency_code"
  t.datetime "settled_at"
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.datetime "up_created_at"  # Created timestamp from Up API
  t.index ["user_id"], name: "index_transactions_on_user_id"
  t.index ["account_id"], name: "index_transactions_on_transactions_account_id"
  t.index ["up_id", "user_id"], name: "index_transactions_on_up_id_and_user_id", unique: true
  t.index ["status"], name: "index_transactions_on_status"
  t.index ["settled_at"], name: "index_transactions_on_settled_at"
  t.index ["user_id", "settled_at"], name: "index_transactions_on_user_and_settled"
end
```

**Fields:**
- `up_id`: Unique identifier from Up API
- `status`: HELD or SETTLED
- `amount`: Transaction amount (negative for debits, positive for credits)
- `settled_at`: When transaction was settled
- `description`: Human-readable description
- `raw_text`: Original transaction text

**Indexes:**
- User ID for user isolation
- Status for filtering
- Settled_at for date range queries
- Composite index for common queries (user + settled_at)

#### categories

```ruby
create_table "categories" do |t|
  t.string "up_id", null: false  # Up API category ID
  t.string "name", null: false
  t.string "parent_id"  # Reference to parent category up_id
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.index ["up_id"], name: "index_categories_on_up_id", unique: true
  t.index ["parent_id"], name: "index_categories_on_parent_id"
end
```

**Note:** Categories are shared across all users (not user-specific in Up API)

#### transaction_categories

```ruby
create_table "transaction_categories" do |t|
  t.bigint "transaction_id", null: false
  t.bigint "category_id", null: false
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.index ["transaction_id"], name: "index_transaction_categories_on_transaction_id"
  t.index ["category_id"], name: "index_transaction_categories_on_category_id"
  t.index ["transaction_id", "category_id"], name: "index_transaction_categories_unique", unique: true
end
```

**Many-to-Many:** Transactions can have multiple categories

#### tags

```ruby
create_table "tags" do |t|
  t.bigint "user_id", null: false
  t.string "name", null: false
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.index ["user_id", "name"], name: "index_tags_on_user_and_name", unique: true
end
```

**User-specific:** Each user has their own tags

#### transaction_tags

```ruby
create_table "transaction_tags" do |t|
  t.bigint "transaction_id", null: false
  t.bigint "tag_id", null: false
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.index ["transaction_id"], name: "index_transaction_tags_on_transaction_id"
  t.index ["tag_id"], name: "index_transaction_tags_on_tag_id"
  t.index ["transaction_id", "tag_id"], name: "index_transaction_tags_unique", unique: true
end
```

#### budgets

```ruby
create_table "budgets" do |t|
  t.bigint "user_id", null: false
  t.bigint "category_id"
  t.string "name", null: false
  t.decimal "amount", precision: 10, scale: 2, null: false
  t.string "period", default: "monthly"  # monthly, weekly, yearly
  t.date "start_date"
  t.date "end_date"
  t.decimal "alert_threshold", precision: 5, scale: 2, default: 80.0  # Alert at 80%
  t.boolean "active", default: true
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.index ["user_id"], name: "index_budgets_on_user_id"
  t.index ["category_id"], name: "index_budgets_on_category_id"
  t.index ["user_id", "active"], name: "index_budgets_on_user_and_active"
end
```

**Fields:**
- `category_id`: Optional - budget for specific category
- `amount`: Budget limit
- `period`: Budget period (monthly, weekly, yearly)
- `alert_threshold`: Percentage at which to alert user

#### investment_goals

```ruby
create_table "investment_goals" do |t|
  t.bigint "user_id", null: false
  t.string "name", null: false
  t.text "description"
  t.decimal "target_amount", precision: 10, scale: 2, null: false
  t.decimal "current_amount", precision: 10, scale: 2, default: 0.0
  t.bigint "account_id"  # Linked saver account
  t.date "target_date"
  t.boolean "active", default: true
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.index ["user_id"], name: "index_investment_goals_on_user_id"
  t.index ["account_id"], name: "index_investment_goals_on_account_id"
end
```

**Fields:**
- `target_amount`: Goal amount
- `current_amount`: Current progress
- `account_id`: Optional link to saver account

#### budget_alerts

```ruby
create_table "budget_alerts" do |t|
  t.bigint "budget_id", null: false
  t.bigint "user_id", null: false
  t.decimal "spent", precision: 10, scale: 2
  t.decimal "limit", precision: 10, scale: 2
  t.decimal "percentage", precision: 5, scale: 2
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.index ["budget_id"], name: "index_budget_alerts_on_budget_id"
  t.index ["user_id", "budget_id", "created_at"], name: "index_budget_alerts_on_user_id_and_budget_id_and_created_at"
  t.index ["user_id"], name: "index_budget_alerts_on_user_id"
end
```

**Fields:**
- Tracks budget alert history when thresholds are reached
- Stores spent amount, limit, and percentage at time of alert

---

## Additional Features

The following tables exist in the system but are beyond the core architecture documented here. They represent additional features for collaboration, planning, and user experience enhancements.

### Collaboration & Project Management

- **projects**: Project containers for expense tracking
- **project_members**: User membership and permissions for projects
- **project_expenses**: Expenses associated with projects
- **expense_contributions**: Individual user contributions to shared expenses

### Transaction Planning & Analysis

- **recurring_transactions**: Detected recurring transaction patterns
- **planned_transactions**: User-created planned/future transactions
- **goals**: Generic goal tracking (separate from investment_goals)

### User Experience

- **notifications**: User notification system
- **filters**: Saved filter configurations for transactions
- **feedback_items**: User feedback and feature requests
- **sessions**: Custom session tracking beyond Devise

### Integration & Storage

- **webhook_events**: Webhook event storage and processing
- **active_storage_attachments**: Active Storage file attachments
- **active_storage_blobs**: Active Storage blob metadata
- **active_storage_variant_records**: Active Storage image variants

**Note:** These features are not part of the core budgeting and investment tracking architecture but extend the application's capabilities.

---

## Models & Relationships

### User Model

```ruby
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :accounts, dependent: :destroy
  has_many :transactions, dependent: :destroy
  has_many :budgets, dependent: :destroy
  has_many :tags, dependent: :destroy
  has_many :investment_goals, dependent: :destroy

  # Rails 8.1.1+ built-in encryption
  encrypts :up_pat

  validates :up_pat, presence: true, on: :update, if: :up_pat_changed?,
    format: { 
      with: /\Aup:yeah:[a-zA-Z0-9]+\z/,
      message: "must be a valid Up Bank Personal Access Token"
    }

  # Scopes
  scope :with_pat, -> { where.not(up_pat_ciphertext: nil) }

  # Methods
  def up_pat_configured?
    up_pat.present?
  end

  def sync_required?
    last_synced_at.nil? || last_synced_at < 1.hour.ago
  end

  def can_access?(resource)
    resource.user_id == id
  end
end
```

**Key Methods:**
- `up_pat`: Encrypted accessor for Personal Access Token
- `up_pat_configured?`: Check if PAT is set
- `sync_required?`: Determine if sync is needed

### Account Model

```ruby
class Account < ApplicationRecord
  belongs_to :user
  has_many :transactions, dependent: :destroy
  has_many :investment_goals

  validates :up_id, presence: true, uniqueness: true
  validates :account_type, inclusion: { in: %w[TRANSACTIONAL SAVER HOME_LOAN] }
  validates :ownership_type, inclusion: { in: %w[INDIVIDUAL JOINT] }

  scope :transactional, -> { where(account_type: 'TRANSACTIONAL') }
  scope :saver, -> { where(account_type: 'SAVER') }
  scope :home_loan, -> { where(account_type: 'HOME_LOAN') }

  def display_name_or_type
    display_name.presence || account_type.humanize
  end
end
```

### Transaction Model

```ruby
class Transaction < ApplicationRecord
  belongs_to :user
  belongs_to :account
  has_many :transaction_categories, dependent: :destroy
  has_many :categories, through: :transaction_categories
  has_many :transaction_tags, dependent: :destroy
  has_many :tags, through: :transaction_tags

  validates :up_id, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[HELD SETTLED] }
  validates :amount, presence: true

  scope :settled, -> { where(status: 'SETTLED') }
  scope :held, -> { where(status: 'HELD') }
  scope :recent, -> { where('settled_at >= ?', 12.months.ago) }
  scope :by_date_range, ->(start_date, end_date) {
    where(settled_at: start_date..end_date)
  }
  scope :by_category, ->(category_id) {
    joins(:categories).where(categories: { id: category_id })
  }

  def debit?
    amount.negative?
  end

  def credit?
    amount.positive?
  end

  def amount_abs
    amount.abs
  end
end
```

### Budget Model

```ruby
class Budget < ApplicationRecord
  belongs_to :user
  belongs_to :category, optional: true

  validates :name, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :period, inclusion: { in: %w[monthly weekly yearly] }
  validates :alert_threshold, numericality: { in: 0..100 }

  scope :active, -> { where(active: true) }
  scope :for_period, ->(date) {
    case period
    when 'monthly'
      where('start_date <= ? AND end_date >= ?', date.end_of_month, date.beginning_of_month)
    when 'weekly'
      where('start_date <= ? AND end_date >= ?', date.end_of_week, date.beginning_of_week)
    when 'yearly'
      where('start_date <= ? AND end_date >= ?', date.end_of_year, date.beginning_of_year)
    end
  }

  def spent_amount(user, date = Date.current)
    return 0 unless category_id

    transactions = user.transactions
      .settled
      .by_category(category_id)
      .by_date_range(period_start(date), period_end(date))

    transactions.sum(&:amount_abs)
  end

  def spent_percentage(user, date = Date.current)
    return 0 if amount.zero?
    (spent_amount(user, date) / amount * 100).round(2)
  end

  def alert_threshold_reached?(user, date = Date.current)
    spent_percentage(user, date) >= alert_threshold
  end

  private

  def period_start(date)
    case period
    when 'monthly' then date.beginning_of_month
    when 'weekly' then date.beginning_of_week
    when 'yearly' then date.beginning_of_year
    end
  end

  def period_end(date)
    case period
    when 'monthly' then date.end_of_month
    when 'weekly' then date.end_of_week
    when 'yearly' then date.end_of_year
    end
  end
end
```

---

## API Integration Layer

### Up API Client Service

```ruby
# app/services/up_api/client.rb
module UpApi
  class Client
    BASE_URL = 'https://api.up.com.au/api/v1'.freeze

    def initialize(personal_access_token)
      @token = personal_access_token
      @connection = build_connection
    end

    def accounts
      get('accounts')
    end

    def account(id)
      get("accounts/#{id}")
    end

    def transactions(params = {})
      get('transactions', params)
    end

    def transaction(id)
      get("transactions/#{id}")
    end

    def categories
      get('categories')
    end

    def category(id)
      get("categories/#{id}")
    end

    private

    def build_connection
      Faraday.new(url: BASE_URL) do |conn|
        conn.request :json
        conn.response :json
        conn.adapter Faraday.default_adapter
        conn.headers['Authorization'] = "Bearer #{@token}"
        conn.headers['Content-Type'] = 'application/json'
      end
    end

    def get(path, params = {})
      response = @connection.get(path, params)
      handle_response(response)
    rescue Faraday::Error => e
      handle_error(e)
    end

    def handle_response(response)
      case response.status
      when 200..299
        response.body
      when 429
        raise UpApi::RateLimitError, 'Rate limit exceeded'
      when 401
        raise UpApi::AuthenticationError, 'Invalid token'
      else
        raise UpApi::ApiError, "API error: #{response.status}"
      end
    end

    def handle_error(error)
      raise UpApi::ApiError, "Network error: #{error.message}"
    end
  end
end
```

### Accounts Sync Service

```ruby
# app/services/up_api/accounts_sync.rb
module UpApi
  class AccountsSync
    def initialize(user)
      @user = user
      @client = Client.new(user.up_pat)
    end

    def sync
      response = @client.accounts
      accounts_data = response['data'] || []

      accounts_data.each do |account_data|
        sync_account(account_data)
      end

      @user.update(last_synced_at: Time.current)
    end

    private

    def sync_account(account_data)
      account = @user.accounts.find_or_initialize_by(up_id: account_data['id'])
      
      attributes = account_data['attributes']
      relationships = account_data['relationships']

      account.assign_attributes(
        account_type: attributes['accountType'],
        ownership_type: attributes['ownershipType'],
        display_name: attributes['displayName'],
        balance: attributes.dig('balance', 'valueInBaseUnits').to_f / 100.0,
        currency_code: attributes.dig('balance', 'currencyCode'),
        up_created_at: attributes['createdAt']
      )

      account.save!
    end
  end
end
```

### Transactions Sync Service

```ruby
# app/services/up_api/transactions_sync.rb
module UpApi
  class TransactionsSync
    def initialize(user, account = nil)
      @user = user
      @account = account
      @client = Client.new(user.up_pat)
    end

    def sync_all(since: nil, until_date: nil)
      since ||= @user.transactions.maximum(:up_created_at) || 12.months.ago
      
      params = {
        'filter[since]' => since.iso8601,
        'page[size]' => 100
      }
      params['filter[until]'] = until_date.iso8601 if until_date

      sync_with_pagination(params)
    end

    def sync_for_account(account)
      @account = account
      sync_all
    end

    private

    def sync_with_pagination(params)
      next_cursor = nil
      total_synced = 0

      loop do
        params['page[after]'] = next_cursor if next_cursor
        response = @client.transactions(params)
        
        transactions_data = response['data'] || []
        transactions_data.each { |data| sync_transaction(data) }
        
        total_synced += transactions_data.size
        links = response['links'] || {}
        next_cursor = extract_cursor(links['next'])

        break unless next_cursor
      end

      total_synced
    end

    def sync_transaction(transaction_data)
      up_id = transaction_data['id']
      transaction = @user.transactions.find_or_initialize_by(up_id: up_id)

      attributes = transaction_data['attributes']
      relationships = transaction_data['relationships']

      # Find or create account
      account_up_id = relationships.dig('account', 'data', 'id')
      account = @account || @user.accounts.find_by!(up_id: account_up_id)

      transaction.assign_attributes(
        account: account,
        status: attributes['status'],
        raw_text: attributes['rawText'],
        description: attributes['description'],
        message: attributes['message'],
        hold_info_is_cover: attributes.dig('holdInfo', 'isCover'),
        amount: attributes.dig('amount', 'valueInBaseUnits').to_f / 100.0,
        currency_code: attributes.dig('amount', 'currencyCode'),
        foreign_amount: attributes.dig('foreignAmount', 'valueInBaseUnits'),
        foreign_currency_code: attributes.dig('foreignAmount', 'currencyCode'),
        settled_at: attributes['settledAt'],
        up_created_at: attributes['createdAt']
      )

      transaction.save!

      # Sync categories
      sync_transaction_categories(transaction, relationships['category'])

      # Sync tags (if any)
      sync_transaction_tags(transaction, relationships['tags'])
    end

    def sync_transaction_categories(transaction, category_data)
      return unless category_data

      category_up_id = category_data.dig('data', 'id')
      category = Category.find_by(up_id: category_up_id)
      return unless category

      transaction.transaction_categories.find_or_create_by(category: category)
    end

    def sync_transaction_tags(transaction, tags_data)
      return unless tags_data && tags_data['data']

      tags_data['data'].each do |tag_data|
        tag_up_id = tag_data['id']
        tag = @user.tags.find_or_create_by(name: tag_up_id)
        transaction.transaction_tags.find_or_create_by(tag: tag)
      end
    end

    def extract_cursor(url)
      return nil unless url
      uri = URI.parse(url)
      params = URI.decode_www_form(uri.query || '').to_h
      params['page[after]']
    end
  end
end
```

---

## Background Jobs

### Sync Accounts Job

```ruby
# app/jobs/sync_accounts_job.rb
class SyncAccountsJob < ApplicationJob
  queue_as :default

  retry_on UpApi::RateLimitError, wait: :exponentially_longer, attempts: 5
  retry_on UpApi::ApiError, wait: 5.seconds, attempts: 3

  def perform(user_id)
    user = User.find(user_id)
    return unless user.up_pat_configured?

    UpApi::AccountsSync.new(user).sync
  rescue UpApi::AuthenticationError => e
    Rails.logger.error "Authentication failed for user #{user_id}: #{e.message}"
    # Could notify user here
  end
end
```

### Sync Transactions Job

```ruby
# app/jobs/sync_transactions_job.rb
class SyncTransactionsJob < ApplicationJob
  queue_as :default

  retry_on UpApi::RateLimitError, wait: :exponentially_longer, attempts: 5
  retry_on UpApi::ApiError, wait: 5.seconds, attempts: 3

  def perform(user_id, account_id = nil)
    user = User.find(user_id)
    return unless user.up_pat_configured?

    account = account_id ? user.accounts.find(account_id) : nil
    sync_service = UpApi::TransactionsSync.new(user, account)
    
    sync_service.sync_all
  rescue UpApi::AuthenticationError => e
    Rails.logger.error "Authentication failed for user #{user_id}: #{e.message}"
  end
end
```

### Calculate Budgets Job

```ruby
# app/jobs/calculate_budgets_job.rb
class CalculateBudgetsJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    
    user.budgets.active.each do |budget|
      if budget.alert_threshold_reached?(user)
        BudgetAlertMailer.threshold_reached(user, budget).deliver_later
      end
    end
  end
end
```

---

## Services & Business Logic

### Budget Calculator Service

```ruby
# app/services/budget_calculator.rb
class BudgetCalculator
  def initialize(user)
    @user = user
  end

  def calculate_for_period(budget, date = Date.current)
    {
      budget: budget,
      limit: budget.amount,
      spent: budget.spent_amount(@user, date),
      remaining: budget.amount - budget.spent_amount(@user, date),
      percentage: budget.spent_percentage(@user, date),
      alert_threshold: budget.alert_threshold,
      alert_triggered: budget.alert_threshold_reached?(@user, date)
    }
  end

  def calculate_all_for_period(date = Date.current)
    @user.budgets.active.map do |budget|
      calculate_for_period(budget, date)
    end
  end
end
```

### Investment Tracker Service

```ruby
# app/services/investment_tracker.rb
class InvestmentTracker
  def initialize(user)
    @user = user
  end

  def track_savings_growth(account, months: 12)
    end_date = Date.current
    start_date = months.months.ago

    transactions = account.transactions
      .settled
      .where('settled_at >= ?', start_date)
      .order(:settled_at)

    balance_history = []
    running_balance = account.balance

    transactions.reverse.each do |transaction|
      running_balance -= transaction.amount
      balance_history.unshift({
        date: transaction.settled_at.to_date,
        balance: running_balance,
        change: transaction.amount
      })
    end

    {
      account: account,
      start_date: start_date,
      end_date: end_date,
      start_balance: balance_history.first&.dig(:balance) || account.balance,
      end_balance: account.balance,
      growth: account.balance - (balance_history.first&.dig(:balance) || account.balance),
      history: balance_history
    }
  end

  def update_investment_goals
    @user.investment_goals.active.each do |goal|
      if goal.account_id
        account = @user.accounts.find(goal.account_id)
        goal.update(current_amount: account.balance)
      end
    end
  end
end
```

---

## Controllers & Routes

### Routes Configuration

```ruby
# config/routes.rb
Rails.application.routes.draw do
  devise_for :users

  root 'dashboard#index'

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
      # PAT updates handled via PATCH /settings (update action)
      # No separate update_pat route needed
    end
  end
end
```

### Dashboard Controller

```ruby
# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @accounts = current_user.accounts.order(:account_type)
    @recent_transactions = current_user.transactions
      .settled
      .recent
      .order(settled_at: :desc)
      .limit(10)
    
    @budget_calculator = BudgetCalculator.new(current_user)
    @budgets_summary = @budget_calculator.calculate_all_for_period
  end
end
```

### Transactions Controller

```ruby
# app/controllers/transactions_controller.rb
class TransactionsController < ApplicationController
  before_action :authenticate_user!

  def index
    @transactions = current_user.transactions
      .settled
      .recent
      .includes(:account, :categories, :tags)
      .order(settled_at: :desc)
      .page(params[:page])

    @transactions = @transactions.by_category(params[:category_id]) if params[:category_id].present?
    @transactions = @transactions.by_date_range(
      params[:start_date]&.to_date || 12.months.ago,
      params[:end_date]&.to_date || Date.current
    ) if params[:start_date].present? || params[:end_date].present?
  end

  def show
    @transaction = current_user.transactions.find(params[:id])
  end
end
```

---

## Error Handling

### Custom Exceptions

```ruby
# app/lib/up_api/errors.rb
module UpApi
  class ApiError < StandardError; end
  class AuthenticationError < ApiError; end
  class RateLimitError < ApiError; end
  class NotFoundError < ApiError; end
end
```

### Application Controller Error Handling

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  rescue_from UpApi::AuthenticationError, with: :handle_authentication_error
  rescue_from UpApi::RateLimitError, with: :handle_rate_limit_error
  rescue_from UpApi::ApiError, with: :handle_api_error

  private

  def handle_authentication_error(exception)
    flash[:alert] = 'Your Up Bank token is invalid. Please update it in settings.'
    redirect_to settings_path
  end

  def handle_rate_limit_error(exception)
    flash[:alert] = 'Rate limit exceeded. Please try again later.'
    redirect_back(fallback_location: root_path)
  end

  def handle_api_error(exception)
    Rails.logger.error "Up API Error: #{exception.message}"
    flash[:alert] = 'An error occurred while fetching data. Please try again.'
    redirect_back(fallback_location: root_path)
  end
end
```

---

**Document Version:** 1.0  
**Last Updated:** December 2025