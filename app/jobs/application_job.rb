require_relative "../../lib/up_api/errors"

class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  # Retry logic for Up API errors

  # Rate limit errors: exponential backoff, 5 attempts
  # Uses retry_after from error if available, otherwise defaults to exponential backoff
  retry_on UpApi::RateLimitError,
           wait: lambda { |job, error|
             # Use retry_after from error if available, otherwise exponential backoff
             error.retry_after || (60 * (2**(job.executions - 1)))
           },
           attempts: 5 do |job, error|
    wait_time = error.retry_after || (60 * (2**(job.executions - 1)))
    Rails.logger.warn "Rate limit hit for job #{job.class.name} (attempt #{job.executions}/5), retrying in #{wait_time} seconds"
  end

  # Server errors: fixed delay, 3 attempts
  retry_on UpApi::ServerError,
           wait: 5.seconds,
           attempts: 3 do |job, error|
    Rails.logger.warn "Server error for job #{job.class.name} (attempt #{job.executions}/3): #{error.message}"
  end

  # General API errors: fixed delay, 3 attempts
  retry_on UpApi::ApiError,
           wait: 5.seconds,
           attempts: 3 do |job, error|
    Rails.logger.warn "API error for job #{job.class.name} (attempt #{job.executions}/3): #{error.message}"
  end

  # Authentication errors: discard immediately (don't retry invalid tokens)
  discard_on UpApi::AuthenticationError do |job, error|
    Rails.logger.error "Authentication failed for job #{job.class.name}, discarding: #{error.message}"
    # Could notify user here in the future
  end

  # Data validation errors: discard (not transient)
  discard_on ActiveRecord::RecordInvalid do |job, error|
    Rails.logger.error "Record validation failed for job #{job.class.name}, discarding: #{error.message}"
  end
end
