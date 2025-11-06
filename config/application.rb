require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Load environment variables from .env files BEFORE environment configs are loaded
# This ensures ENV variables are available when config/environments/*.rb files run
if File.exist?(".env.#{ENV.fetch('RAILS_ENV', 'development')}")
  require "dotenv"
  Dotenv.load(".env.#{ENV.fetch('RAILS_ENV', 'development')}")
elsif File.exist?(".env")
  require "dotenv"
  Dotenv.load(".env")
end

module Vantura
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # Set the default time zone to UTC for consistency
    # User-facing times should be converted to user's timezone in views if needed
    config.time_zone = "UTC"
    config.active_record.default_timezone = :utc

    # config.eager_load_paths << Rails.root.join("extras")
  end
end
