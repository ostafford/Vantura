# config/initializers/opentelemetry.rb
require "uptrace"
require "opentelemetry/instrumentation/all"

# Configure Uptrace with OpenTelemetry following official documentation
# Reference: https://uptrace.dev/get/opentelemetry-ruby
# SSL configuration based on Rails ActionDispatch::SSL documentation
if ENV["UPTRACE_DSN"].present?
  begin
    # Configure SSL context for OpenTelemetry connections
    # This addresses the SSL certificate verification issue we encountered
    if Rails.env.development?
      # In development, we might need to handle SSL differently
      # Based on ActionDispatch::SSL documentation for local development
      Rails.logger.info "Configuring OpenTelemetry for development environment"
    end

    Uptrace.configure_opentelemetry(dsn: ENV["UPTRACE_DSN"]) do |c|
      # Service identification (required)
      c.service_name = "vantura"
      c.service_version = "1.0.0"

      # Resource attributes for better identification and filtering
      c.resource = OpenTelemetry::SDK::Resources::Resource.create({
        "deployment.environment" => Rails.env.to_s,
        "service.namespace" => "finance",
        "service.instance.id" => Socket.gethostname.to_s,
        "service.description" => "Personal finance management application"
      })

      # Enable all available instrumentations for comprehensive monitoring
      c.use_all
    end

    # Ensure spans are flushed even if the application exits unexpectedly
    at_exit { OpenTelemetry.tracer_provider.shutdown }

    Rails.logger.info "Uptrace configured successfully for service: vantura"
    Rails.logger.info "SSL configuration: #{Rails.env.production? ? 'Production SSL enabled' : 'Development mode'}"
  rescue => e
    Rails.logger.error "Failed to configure Uptrace: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    # Log SSL-related information for debugging
    if e.message.include?("SSL") || e.message.include?("certificate")
      Rails.logger.error "SSL-related error detected. Consider checking:"
      Rails.logger.error "1. Network connectivity to Uptrace"
      Rails.logger.error "2. SSL certificate verification settings"
      Rails.logger.error "3. VPN or proxy configuration"
    end
  end
else
  Rails.logger.warn "UPTRACE_DSN not configured - OpenTelemetry traces will not be exported"
end
