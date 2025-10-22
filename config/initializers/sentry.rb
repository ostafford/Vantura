# Sentry Error Tracking Configuration
# Based on: https://docs.sentry.io/platforms/ruby/guides/rails/
# And: https://guides.rubyonrails.org/error_reporting.html
#
# Sentry automatically registers itself as a Rails error reporter subscriber,
# so all errors captured by Rails.error will also be sent to Sentry.

Sentry.init do |config|
  # Sentry DSN - retrieve from Rails credentials
  # To set this, run: bin/rails credentials:edit
  # Then add:
  #   sentry:
  #     dsn: https://YOUR_DSN@o0.ingest.sentry.io/0
  config.dsn = Rails.application.credentials.dig(:sentry, :dsn)
  
  # Only enable in production and staging (not development/test)
  config.enabled_environments = %w[production staging]
  
  # Set current environment
  config.environment = Rails.env
  
  # Breadcrumbs capture context leading up to errors
  # This helps understand what the user was doing before the error occurred
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  
  # Send additional user context (IP, headers, etc.)
  # Note: This may include PII - adjust based on your privacy policy
  config.send_default_pii = true
  
  # Performance Monitoring (Tracing)
  # Set to 1.0 to capture 100% of transactions for performance monitoring
  # In production, you may want to lower this (e.g., 0.1 for 10%)
  # Set to nil or 0 to disable performance monitoring
  config.traces_sample_rate = Rails.env.production? ? 0.1 : 1.0
  
  # Profiling (if you want detailed performance profiles)
  # This is relative to traces_sample_rate
  # Disabled by default - uncomment to enable
  # config.profiles_sample_rate = 1.0
  
  # Release tracking - helps identify which version had issues
  # This will use the current git SHA as the release identifier
  config.release = ENV['KAMAL_VERSION'] || ENV['GIT_REVISION'] || `git rev-parse --short HEAD`.strip rescue nil
  
  # Filter sensitive parameters (in addition to Rails parameter filtering)
  config.excluded_exceptions += [
    'ActionController::RoutingError',  # Don't report 404s
    'ActionController::InvalidAuthenticityToken'  # Don't report CSRF token mismatches
  ]
  
  # Send all errors from these paths
  config.rails.report_rescued_exceptions = true
  
  # Configure which Rails components to instrument
  config.rails.skippable_job_adapters = ["ActiveJob::QueueAdapters::SolidQueueAdapter"]
  
  # Before sending to Sentry, you can modify or filter events
  config.before_send = lambda do |event, hint|
    # Add custom tags
    event.tags[:application] = 'vantura'
    
    # Don't send errors in development/test unless explicitly enabled
    return nil if Rails.env.development? || Rails.env.test?
    
    event
  end
  
  # Tags are set using before_send instead (already configured above)
end

# Log Sentry initialization status
if Sentry.configuration.enabled_environments.include?(Rails.env)
  Rails.logger.info "✅ Sentry error tracking initialized for #{Rails.env} environment"
else
  Rails.logger.info "⏸️  Sentry error tracking disabled for #{Rails.env} environment"
end

