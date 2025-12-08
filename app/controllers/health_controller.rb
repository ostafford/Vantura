# frozen_string_literal: true

class HealthController < ApplicationController
  # Skip authentication for health checks
  skip_before_action :authenticate_user!

  def full
    checks = {
      database: check_database,
      redis: check_redis,
      solid_queue: check_solid_queue,
      up_bank_api: check_up_bank_api
    }

    overall_status = checks.values.all? { |check| check[:status] == "ok" } ? "ok" : "degraded"

    status_code = overall_status == "ok" ? 200 : 503

    render json: {
      status: overall_status,
      timestamp: Time.current.iso8601,
      checks: checks
    }, status: status_code
  end

  private

  def check_database
    start_time = Time.current
    ActiveRecord::Base.connection.execute("SELECT 1")
    response_time = ((Time.current - start_time) * 1000).round(2)

    {
      status: "ok",
      response_time_ms: response_time
    }
  rescue StandardError => e
    {
      status: "error",
      error: e.message
    }
  end

  def check_redis
    start_time = Time.current
    redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
    redis.ping
    response_time = ((Time.current - start_time) * 1000).round(2)

    {
      status: "ok",
      response_time_ms: response_time
    }
  rescue StandardError => e
    {
      status: "error",
      error: e.message
    }
  end

  def check_solid_queue
    start_time = Time.current
    begin
      # Query Solid Queue job statistics
      # Jobs are pending if they haven't finished yet
      pending_count = SolidQueue::Job.where(finished_at: nil).count
      failed_count = SolidQueue::FailedExecution.count
      finished_count = SolidQueue::Job.where.not(finished_at: nil).count
      
      response_time = ((Time.current - start_time) * 1000).round(2)

      {
        status: "ok",
        response_time_ms: response_time,
        pending: pending_count,
        failed: failed_count,
        finished: finished_count
      }
    rescue StandardError => e
      {
        status: "error",
        error: e.message
      }
    end
  end

  def check_up_bank_api
    # Just check if we can reach the API (without auth)
    # 401 is expected without auth, but means API is reachable
    start_time = Time.current
    response = HTTParty.get(
      "https://api.up.com.au/api/v1",
      timeout: 5
    )
    response_time = ((Time.current - start_time) * 1000).round(2)

    {
      status: (response.success? || response.code == 401) ? "ok" : "error",
      response_time_ms: response_time,
      http_status: response.code
    }
  rescue StandardError => e
    {
      status: "error",
      error: e.message
    }
  end
end
