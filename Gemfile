source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.4"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"
# devise for authentication
gem "devise", "~> 4.9", ">= 4.9.4"
# sidekiq for background jobs
gem "sidekiq", "~> 8.0", ">= 8.0.9"
gem "redis", "~> 5.4", ">= 5.4.1"
# pundit for authorization
gem "pundit", "~> 2.5", ">= 2.5.2"
# rack-attack for rate limiting
gem "rack-attack", "~> 6.8"
# money-rails for currency handling
gem "money-rails", "~> 1.15"
# ice-cube for scheduling
gem "ice_cube", "~> 0.17.0"
# dotenv for environment variables
gem "dotenv-rails", "~> 3.1", ">= 3.1.8"
# pagy for pagination
gem "pagy", "~> 43.1", ">= 43.1.8"
# rspec for testing
gem "rspec-rails", "~> 8.0", ">= 8.0.2"
# faker for testing
gem "faker", "~> 3.5", ">= 3.5.2"
# factory_bot for testing
gem "factory_bot", "~> 6.5", ">= 6.5.6"
# shoulda-matchers for testing
gem "shoulda-matchers", "~> 6.4"
# rails-controller-testing for controller tests
gem "rails-controller-testing", "~> 1.0"
# blueprint for views
gem "blueprinter", "~> 1.2", ">= 1.2.1"
# image_processing for image processing
gem "image_processing", "~> 1.14"
# pry-rails for debugging
gem "pry-rails", "~> 0.3.11"
# administrate for admin panel
gem "administrate", "~> 1.0"
# attr_encrypted for encrypted attributes
gem "attr_encrypted", "~> 4.2"
# vcr for recording and playing back HTTP requests
gem "vcr", "~> 6.3", ">= 6.3.1"
# httparty for HTTP client
gem "httparty", "~> 0.23.2"


# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue", "~> 1.2", ">= 1.2.4"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # webmock for HTTP request stubbing (required by VCR)
  gem "webmock", "~> 3.26", ">= 3.26.1"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
  gem "rubocop-performance", "~> 1.26", ">= 1.26.1"
  gem "rubocop-rspec", "~> 3.8", ">= 3.8.0"
  gem "rubocop-rails", "~> 2.34", ">= 2.34.2"
  gem "rubocop", "~> 1.81", ">= 1.81.7"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end
