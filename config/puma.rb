# Puma configuration optimized for production deployment
# Based on Rails Performance Tuning Guide: https://guides.rubyonrails.org/tuning_performance_for_deployment.html
# Reference: https://puma.io/puma/Puma/DSL.html

# Environment-specific configuration
environment ENV.fetch("RAILS_ENV", "development")

# Thread configuration
# Based on Rails Performance Tuning Guide: https://guides.rubyonrails.org/tuning_performance_for_deployment.html
# For well-crafted Rails apps, 3 threads per worker is optimal
# More threads can hurt latency if I/O operations are < 50% of request time
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

# Worker configuration
# In production: Set to number of CPU cores for optimal utilization
# Development: Keep at 1 for easier debugging
if ENV["RAILS_ENV"] == "production"
  # Auto-detect CPU cores or use WEB_CONCURRENCY env var
  # Use sysctl for macOS compatibility
  cpu_cores = ENV.fetch("WEB_CONCURRENCY") do
    if RUBY_PLATFORM.include?("darwin")
      `sysctl -n hw.ncpu`.to_i
    else
      `nproc`.to_i
    end
  end
  workers cpu_cores
else
  # Development: Single worker for easier debugging
  workers ENV.fetch("WEB_CONCURRENCY", 1)
end

# Port configuration
port ENV.fetch("PORT", 3000)

# Preload application for better memory efficiency in production
# This reduces memory usage through copy-on-write optimization
preload_app!

# Worker timeout configuration
# Kill workers that hang for more than 30 seconds
worker_timeout 30

# Worker boot configuration
# This runs before each worker process starts
on_worker_boot do
  # Reconnect to database after worker fork
  if defined?(ActiveRecord::Base)
    ActiveRecord::Base.establish_connection
  end
end

# Master process configuration
# This runs when the master process starts
before_fork do
  # Disconnect from database in master process
  if defined?(ActiveRecord::Base)
    ActiveRecord::Base.connection_pool.disconnect!
  end
end

# Plugin configuration
plugin :tmp_restart

# Run the Solid Queue supervisor inside of Puma for single-server deployments
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]

# PID file configuration
pidfile ENV["PIDFILE"] if ENV["PIDFILE"]

# Logging configuration
if ENV["RAILS_ENV"] == "production"
  # Production: Log to STDOUT for containerized deployments
  stdout_redirect nil, nil, true
end

# Performance optimizations
# Enable worker timeout for better stability
worker_timeout 30

# Configure worker memory limits (optional)
# worker_memory_limit 512 # MB per worker
