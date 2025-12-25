# Deployment & Operations
## Render Deployment, Database Setup, and Monitoring

**Document Version:** 1.0  
**Last Updated:** December 2025  
**Related:** [Architecture Overview](./01-architecture-overview.md)

---

## Table of Contents

1. [Render Platform Overview](#render-platform-overview)
2. [Application Deployment](#application-deployment)
3. [Database Setup](#database-setup)
4. [Environment Configuration](#environment-configuration)
5. [Background Jobs Setup](#background-jobs-setup)
6. [Monitoring & Logging](#monitoring--logging)
7. [Backup Strategy](#backup-strategy)
8. [Scaling Considerations](#scaling-considerations)

---

## Render Platform Overview

### Render Services Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Render Platform                      │
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │         Web Service (Rails App)                  │   │
│  │  - Auto-deploy from Git                          │   │
│  │  - HTTPS enabled                                 │   │
│  │  - Public URL: *.onrender.com                    │   │
│  │  - Health checks                                 │   │
│  └──────────────────────────────────────────────────┘   │
│                          │                              │
│                          │ Connects to                  │
│                          ▼                              │
│  ┌──────────────────────────────────────────────────┐   │
│  │      PostgreSQL Database (Managed)               │   │
│  │  - Automatic backups                             │   │
│  │  - Point-in-time recovery                        │   │
│  │  - High availability                             │   │
│  └──────────────────────────────────────────────────┘   │
│                          │                              │
│                          │ Used by                      │
│                          ▼                              │
│  ┌──────────────────────────────────────────────────┐   │
│  │    Background Worker (Solid Queue)               │   │
│  │  - Separate service                              │   │
│  │  - Job processing                                │   │
│  │  - Uses PostgreSQL (no Redis needed)             │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### Render Service Types

1. **Web Service:** Main Rails application
2. **PostgreSQL Database:** Managed database service
3. **Background Worker:** Solid Queue for job processing (Rails 8 built-in)

---

## Application Deployment

### Render Blueprint Configuration

```yaml
# render.yaml
services:
  # Web Service
  - type: web
    name: up-bank-desktop
    env: ruby
    plan: starter  # $7/month, upgrade as needed
    buildCommand: bundle install && bundle exec rails assets:precompile
    startCommand: bundle exec puma -C config/puma.rb
    envVars:
      - key: RAILS_ENV
        value: production
      - key: RAILS_MASTER_KEY
        sync: false  # Set in Render dashboard
      - key: DATABASE_URL
        fromDatabase:
          name: up-bank-db
          property: connectionString
    healthCheckPath: /up

  # Background Worker
  - type: worker
    name: up-bank-worker
    env: ruby
    plan: starter
    buildCommand: bundle install
    startCommand: bundle exec rake solid_queue:start
    envVars:
      - key: RAILS_ENV
        value: production
      - key: RAILS_MASTER_KEY
        sync: false
      - key: DATABASE_URL
        fromDatabase:
          name: up-bank-db
          property: connectionString

databases:
  # PostgreSQL Database
  - name: up-bank-db
    plan: starter  # $7/month, 1GB storage
    databaseName: up_bank_production
    user: up_bank_user
```

### Manual Service Setup (Alternative)

If not using Blueprint:

1. **Create Web Service:**
   - Type: Web Service
   - Environment: Ruby
   - Build Command: `bundle install && bundle exec rails assets:precompile`
   - Start Command: `bundle exec puma -C config/puma.rb`
   - Health Check Path: `/up`

2. **Create PostgreSQL Database:**
   - Type: PostgreSQL
   - Name: `up-bank-db`
   - Plan: Starter ($7/month)

3. **Create Background Worker:**
   - Type: Background Worker
   - Environment: Ruby
   - Build Command: `bundle install`
   - Start Command: `bundle exec rake solid_queue:start`

### Puma Configuration

```ruby
# config/puma.rb
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

worker_timeout 3600 if ENV.fetch("RAILS_ENV", "development") == "development"

port ENV.fetch("PORT") { 3000 }

environment ENV.fetch("RAILS_ENV") { "development" }

pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

workers ENV.fetch("WEB_CONCURRENCY") { 2 }

preload_app!

plugin :tmp_restart
```

### Health Check Endpoint

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Health check for Render
  get '/up', to: 'health#check'
end
```

```ruby
# app/controllers/health_controller.rb
class HealthController < ApplicationController
  skip_before_action :authenticate_user!

  def check
    render json: {
      status: 'ok',
      timestamp: Time.current.iso8601,
      database: database_status
    }, status: :ok
  end

  private

  def database_status
    ActiveRecord::Base.connection.execute('SELECT 1')
    'connected'
  rescue => e
    'error'
  end
end
```

---

## Database Setup

### Database Migration

```ruby
# db/migrate/XXXXXX_create_schema.rb
class CreateSchema < ActiveRecord::Migration[7.0]
  def change
    # Users table (Devise + PAT)
    create_table :users do |t|
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.text :up_pat_ciphertext  # Rails 8.1.1+ encryption stores IV/salt/metadata inside ciphertext JSON
      t.datetime :last_synced_at

      t.index :email, unique: true
      t.index :reset_password_token, unique: true
    end

    # Accounts table
    create_table :accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :up_id, null: false
      t.string :account_type, null: false
      t.string :ownership_type, null: false
      t.string :display_name
      t.decimal :balance, precision: 10, scale: 2, null: false
      t.string :currency_code, default: "AUD"
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.datetime :up_created_at

      t.index :up_id, unique: true
      t.index [:user_id, :account_type]
    end

    # Transactions table
    create_table :transactions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.string :up_id, null: false
      t.string :status, null: false
      t.string :raw_text
      t.text :description
      t.string :message
      t.boolean :hold_info_is_cover, default: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :currency_code, default: "AUD"
      t.string :foreign_amount
      t.string :foreign_currency_code
      t.datetime :settled_at
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.datetime :up_created_at

      t.index :up_id, unique: true
      t.index :status
      t.index :settled_at
      t.index [:user_id, :settled_at]
    end

    # Categories (shared across users)
    create_table :categories do |t|
      t.string :up_id, null: false
      t.string :name, null: false
      t.string :parent_id
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.index :up_id, unique: true
      t.index :parent_id
    end

    # Transaction Categories (many-to-many)
    create_table :transaction_categories do |t|
      t.references :transaction, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.index [:transaction_id, :category_id], unique: true
    end

    # Tags (user-specific)
    create_table :tags do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.index [:user_id, :name], unique: true
    end

    # Transaction Tags (many-to-many)
    create_table :transaction_tags do |t|
      t.references :transaction, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.index [:transaction_id, :tag_id], unique: true
    end

    # Budgets
    create_table :budgets do |t|
      t.references :user, null: false, foreign_key: true
      t.references :category, foreign_key: true
      t.string :name, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :period, default: "monthly"
      t.date :start_date
      t.date :end_date
      t.decimal :alert_threshold, precision: 5, scale: 2, default: 80.0
      t.boolean :active, default: true
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.index [:user_id, :active]
    end

    # Investment Goals
    create_table :investment_goals do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.decimal :target_amount, precision: 10, scale: 2, null: false
      t.decimal :current_amount, precision: 10, scale: 2, default: 0.0
      t.references :account, foreign_key: true
      t.date :target_date
      t.boolean :active, default: true
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.index :user_id
    end
  end
end
```

### Database Configuration

```yaml
# config/database.yml
production:
  <<: *default
  url: <%= ENV['DATABASE_URL'] %>
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000
```

### Running Migrations

```bash
# On Render, migrations run automatically on deploy
# Or manually via Render shell:
bundle exec rails db:migrate
```

---

## Environment Configuration

### What is CI/CD?

**CI/CD = Continuous Integration / Continuous Deployment**

**What It Does:**
Automatically tests your code and deploys it when you push to GitHub.

**Without CI/CD:**
1. You push code to GitHub
2. Render deploys immediately
3. If code has bugs → Production breaks → Users affected

**With CI/CD:**
1. You push code to GitHub
2. GitHub Actions runs tests automatically
3. If tests fail → Deployment blocked, you get notification
4. If tests pass → Render deploys automatically
5. Production never breaks from bugs caught by tests

**Setup (Recommended for Post-MVP):**
```yaml
# .github/workflows/test.yml
name: Test Suite
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:14
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.2
          bundler-cache: true
      
      - name: Setup Database
        env:
          DATABASE_URL: postgres://postgres:postgres@localhost:5432/test
        run: |
          bundle exec rails db:create
          bundle exec rails db:migrate
      
      - name: Run Tests
        env:
          DATABASE_URL: postgres://postgres:postgres@localhost:5432/test
        run: bundle exec rspec
      
      - name: Run Linter
        run: bundle exec rubocop
```

**Cost:** Free (GitHub Actions is free for public repos, 2,000 minutes/month for private repos)

**Recommendation:** Start without CI/CD for MVP, add it after launch when you have tests written.

### What is a Staging Environment?

**Definition:** A staging environment is a complete copy of your production application running in a separate environment for testing.

**Why You Need It:**
1. **Test Before Production:** Deploy new features to staging first, test them, then deploy to production
2. **Webhook Testing:** Test Up Bank webhooks with real API without affecting production data
3. **Data Migration Testing:** Test database migrations safely before running on production
4. **Client Review:** Show clients/stakeholders new features before launching

**Cost:** Render staging uses free/starter tier ($7/month total), production uses paid tier

**Workflow:**
```
Local Development → Push to 'develop' branch → Auto-deploys to Staging
→ Test on staging → Merge 'develop' to 'main' → Auto-deploys to Production
```

**Example:**
- Production: https://vantura.com (users use this)
- Staging: https://staging-vantura.onrender.com (you test here first)

### Required Environment Variables

Set in Render Dashboard → Environment:

```bash
# Rails Encryption (automatically configured via credentials)
# No need to set these as environment variables - they're in credentials.yml.enc:
# - active_record_encryption.primary_key
# - active_record_encryption.deterministic_key
# - active_record_encryption.key_derivation_salt

# RAILS_MASTER_KEY unlocks credentials.yml.enc which contains encryption keys
RAILS_MASTER_KEY=<from credentials.yml.enc>
```
**Important:** The `RAILS_MASTER_KEY` environment variable is critical - it decrypts your `credentials.yml.enc` file, which contains your encryption keys. Keep this secure and never commit it to version control.

**Render Setup:**
1. Generate master key: Already created when you run `rails credentials:edit`
2. Copy from: `config/master.key` (or generate new: `rails credentials:edit`)
3. Set in Render Dashboard: Environment Variables → `RAILS_MASTER_KEY`

### Rails Credentials

```bash
# Edit credentials
EDITOR="code --wait" rails credentials:edit

# In credentials.yml.enc, add:
secret_key_base: <generated-secret>
```

### Environment-Specific Config

```ruby
# config/environments/production.rb
Rails.application.configure do
  config.cache_classes = true
  config.eager_load = true
  config.consider_all_requests_local = false
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?
  config.force_ssl = true
  config.log_level = :info
  config.log_tags = [ :request_id ]
  
  # Use Render's log drain
  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger = ActiveSupport::TaggedLogging.new(logger)
  end

  config.active_record.dump_schema_after_migration = false
end
```

---

## Background Jobs Setup
```ruby
# config/initializers/web_push.rb
WebPush.generate_key.tap do |key|
  Rails.application.credentials.web_push ||= {}
  Rails.application.credentials.web_push[:vapid] = {
    subject: ENV['VAPID_SUBJECT'] || 'mailto:your-email@vantura.com',
    public_key: key.public_key,
    private_key: key.private_key
  }
end

# app/models/push_subscription.rb
class PushSubscription < ApplicationRecord
  belongs_to :user
  
  validates :endpoint, presence: true, uniqueness: true
  validates :p256dh_key, presence: true
  validates :auth_key, presence: true
end

# Migration
create_table :push_subscriptions do |t|
  t.references :user, null: false, foreign_key: true
  t.string :endpoint, null: false
  t.string :p256dh_key, null: false
  t.string :auth_key, null: false
  t.timestamps
  
  t.index :endpoint, unique: true
end

# app/services/push_notification_service.rb
class PushNotificationService
  def initialize(user)
    @user = user
  end

  def send_notification(title:, body:, url: nil)
    @user.push_subscriptions.each do |subscription|
      send_push(subscription, title: title, body: body, url: url)
    end
  end

  private

  def send_push(subscription, title:, body:, url:)
    message = {
      title: title,
      body: body,
      url: url,
      icon: '/icons/icon-192x192.png',
      badge: '/icons/badge-72x72.png'
    }.to_json

    WebPush.payload_send(
      message: message,
      endpoint: subscription.endpoint,
      p256dh: subscription.p256dh_key,
      auth: subscription.auth_key,
      vapid: Rails.application.credentials.web_push[:vapid]
    )
  rescue WebPush::InvalidSubscription, WebPush::ExpiredSubscription
    subscription.destroy
  end
end
```

### Solid Queue Configuration

Solid Queue is Rails 8's built-in background job processor that uses PostgreSQL instead of Redis.

```ruby
# config/application.rb
config.active_job.queue_adapter = :solid_queue
```

```ruby
# config/initializers/solid_queue.rb
SolidQueue.middleware do |chain|
  # Add any middleware you need
end

# Configure job scheduling (using whenever gem or similar)
# config/schedule.rb
every 1.hour do
  runner "SyncAllUsersJob.perform_later"
end

every 1.day, at: '9:00 am' do
  runner "CheckBudgetAlertsJob.perform_later"
end

every 1.day, at: '2:00 am' do
  runner "FullSyncAllUsersJob.perform_later"
end
```

**Note:** Solid Queue uses PostgreSQL tables to store jobs, so no Redis is needed. Jobs are stored in the `solid_queue_jobs` table.

---

## Monitoring & Logging

### Render Logs

Render provides built-in log aggregation:

- **Access Logs:** HTTP requests and responses
- **Application Logs:** Rails logs (stdout/stderr)
- **Build Logs:** Deployment build process

View logs in Render Dashboard → Logs tab.

### Application Logging

```ruby
# config/environments/production.rb
config.log_level = :info
config.log_formatter = ::Logger::Formatter.new

# Log to stdout for Render
if ENV["RAILS_LOG_TO_STDOUT"].present?
  logger = ActiveSupport::Logger.new(STDOUT)
  logger.formatter = config.log_formatter
  config.logger = ActiveSupport::TaggedLogging.new(logger)
end
```

### Custom Logging

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  around_action :log_request

  private

  def log_request
    start_time = Time.current
    yield
    duration = Time.current - start_time
    
    Rails.logger.info({
      method: request.method,
      path: request.path,
      status: response.status,
      duration: duration,
      user_id: current_user&.id
    }.to_json)
  end
end
```

### Error Tracking (Optional)

```ruby
# Gemfile
gem 'sentry-ruby'
gem 'sentry-rails'

# config/initializers/sentry.rb
Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.traces_sample_rate = 0.5
end
```

---

## Backup Strategy

### Render Automatic Backups

Render PostgreSQL provides:

- **Daily Backups:** Automatic daily backups
- **Point-in-Time Recovery:** Available on paid plans
- **Manual Backups:** Create on-demand via dashboard

### Backup Configuration

1. **Enable Backups:**
   - Render Dashboard → Database → Settings
   - Enable "Automatic Backups"
   - Set retention period (7-30 days)

2. **Manual Backup:**
   ```bash
   # Via Render dashboard or CLI
   render backups:create --database up-bank-db
   ```

3. **Restore Backup:**
   - Render Dashboard → Database → Backups
   - Select backup → Restore

### Data Export (Additional Safety)

```ruby
# lib/tasks/backup.rake
namespace :backup do
  desc "Export database to file"
  task :export => :environment do
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    filename = "backup_#{timestamp}.sql"
    
    system("pg_dump #{ENV['DATABASE_URL']} > #{filename}")
    
    puts "Backup created: #{filename}"
  end
end
```

---

## Scaling Considerations

### Current Scale (Initial)

- **Users:** ~5 users
- **Transactions:** ~3,000 per user (~15,000 total)
- **Database Size:** ~100-500 MB
- **Web Service:** Starter plan ($7/month) sufficient
- **Database:** Starter plan ($7/month) sufficient
- **Background Worker:** Starter plan ($7/month) sufficient

**Total Initial Cost:** $21/month (Web $7 + Database $7 + Worker $7)

### Scaling Indicators

Monitor these metrics:

1. **Response Time:** > 2 seconds average
2. **Database Size:** > 80% of plan limit
3. **Memory Usage:** > 80% consistently
4. **CPU Usage:** > 80% consistently
5. **Error Rate:** > 1% of requests

### Scaling Options

**Web Service:**
- Starter → Standard ($25/month): More RAM, CPU
- Add more workers if needed

**Database:**
- Starter → Standard ($20/month): More storage, better performance
- Add read replicas if needed

**Background Workers:**
- Add additional worker instances
- Scale based on queue depth

### Performance Optimization

```ruby
# Add database indexes for common queries
add_index :transactions, [:user_id, :settled_at, :status]
add_index :accounts, [:user_id, :account_type]
add_index :budgets, [:user_id, :active, :period]

# Use database connection pooling
config.active_record.pool = ENV.fetch("RAILS_MAX_THREADS") { 5 }

# Enable query caching
config.active_record.query_cache_enabled = true
```

---

## Deployment Checklist

### Pre-Deployment

- [ ] All tests passing
- [ ] Database migrations ready
- [ ] Environment variables configured
- [ ] Rails credentials set
- [ ] Health check endpoint working
- [ ] SSL certificate valid (Render automatic)

### Deployment Steps

1. **Push to Git:**
   ```bash
   git add .
   git commit -m "Deploy to production"
   git push origin main
   ```

2. **Render Auto-Deploys:**
   - Render detects push
   - Runs build command
   - Runs migrations (if configured)
   - Restarts services

3. **Verify Deployment:**
   - Check health endpoint: `https://your-app.onrender.com/up`
   - Test user registration
   - Test PAT configuration
   - Test data sync

### Post-Deployment

- [ ] Verify all services running
- [ ] Check application logs
- [ ] Test critical user flows
- [ ] Monitor error rates
- [ ] Verify background jobs running

---

**Document Version:** 1.0  
**Last Updated:** December 2025