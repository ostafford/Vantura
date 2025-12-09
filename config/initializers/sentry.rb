# frozen_string_literal: true

# Configure Sentry for error reporting
# Reference: https://guides.rubyonrails.org/error_reporting.html
# Set SENTRY_DSN environment variable in production

Sentry.init do |config|
  config.dsn = ENV.fetch("SENTRY_DSN", nil)
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  # Set environment
  config.environment = Rails.env

  # Filter sensitive data
  config.before_send = lambda do |event, hint|
    # Filter sensitive parameters
    if event.request
      event.request.data = filter_sensitive_data(event.request.data)
    end
    event
  end

  # Only send errors in production and staging
  config.enabled_environments = %w[production staging]

  # Set sample rate for performance monitoring (0.0 to 1.0)
  config.traces_sample_rate = Rails.env.production? ? 0.1 : 0.0

  # Release tracking (optional - set via SENTRY_RELEASE env var)
  config.release = ENV.fetch("SENTRY_RELEASE", nil)
end

# Helper method to filter sensitive data
# Reference: https://guides.rubyonrails.org/error_reporting.html#filtering-sensitive-data
def filter_sensitive_data(data)
  return data unless data.is_a?(Hash)

  sensitive_keys = %w[password password_confirmation token secret key api_key access_token refresh_token]
  
  data.each_with_object({}) do |(key, value), filtered|
    key_str = key.to_s.downcase
    
    # Check if this key is sensitive (exact match or contains sensitive term)
    is_sensitive = sensitive_keys.any? do |sensitive|
      key_str == sensitive.downcase || key_str.include?(sensitive.downcase)
    end
    
    if is_sensitive
      filtered[key] = "[FILTERED]"
    elsif value.is_a?(Hash)
      filtered[key] = filter_sensitive_data(value)
    else
      filtered[key] = value
    end
  end
end

