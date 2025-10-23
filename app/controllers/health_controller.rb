# app/controllers/health_controller.rb
class HealthController < ApplicationController
  # Skip CSRF protection for health check endpoints
  skip_before_action :verify_authenticity_token, only: [:show, :detailed]

  # Basic health check endpoint
  def show
    render plain: "OK", status: :ok
  rescue => e
    render plain: "Error: #{e.message}", status: :internal_server_error
  end

  # Detailed health check endpoint
  def detailed
    status = {
      application: {
        status: "UP",
        version: Rails.application.config.x.app_version || "1.0.0",
        environment: Rails.env,
        ruby_version: RUBY_VERSION,
        rails_version: Rails.version
      },
      database: check_database_health,
      redis: check_redis_health,
      timestamp: Time.current
    }

    if status[:database][:status] == "DOWN" || status[:redis][:status] == "DOWN"
      render json: status, status: :service_unavailable
    else
      render json: status, status: :ok
    end
  rescue => e
    render json: { error: e.message, backtrace: e.backtrace }, status: :internal_server_error
  end

  private

  def check_database_health
    ActiveRecord::Base.connection.execute("SELECT 1")
    { status: "UP", message: "Database connection successful" }
  rescue => e
    { status: "DOWN", message: "Database connection failed: #{e.message}" }
  end

  def check_redis_health
    # Assuming Redis is configured, e.g., for caching or Action Cable
    # If Redis is not used, this method can be removed or adapted
    if defined?(Redis) && Rails.cache.respond_to?(:redis)
      Rails.cache.redis.ping
      { status: "UP", message: "Redis connection successful" }
    else
      { status: "N/A", message: "Redis not configured or not applicable" }
    end
  rescue => e
    { status: "DOWN", message: "Redis connection failed: #{e.message}" }
  end
end
