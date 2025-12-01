# frozen_string_literal: true

namespace :monitoring do
  desc "Check system health (database, Redis, Sidekiq, Up Bank API)"
  task check: :environment do
    puts "=== System Health Check ==="
    puts "Timestamp: #{Time.current.iso8601}"
    puts ""

    # Database check
    print "Database: "
    begin
      start_time = Time.current
      ActiveRecord::Base.connection.execute("SELECT 1")
      response_time = ((Time.current - start_time) * 1000).round(2)
      puts "✓ OK (#{response_time}ms)"
    rescue StandardError => e
      puts "✗ ERROR: #{e.message}"
    end

    # Redis check
    print "Redis: "
    begin
      start_time = Time.current
      redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
      redis.ping
      response_time = ((Time.current - start_time) * 1000).round(2)
      puts "✓ OK (#{response_time}ms)"
    rescue StandardError => e
      puts "✗ ERROR: #{e.message}"
    end

    # Sidekiq check
    print "Sidekiq: "
    begin
      require "sidekiq/api" unless defined?(Sidekiq::Stats)
      if defined?(Sidekiq::Stats)
        stats = Sidekiq::Stats.new
        puts "✓ OK (Processed: #{stats.processed}, Failed: #{stats.failed}, Enqueued: #{stats.enqueued})"
      else
        puts "⚠ WARNING: Sidekiq::Stats not available"
      end
    rescue LoadError => e
      puts "⚠ WARNING: Sidekiq gem not available (#{e.message})"
    rescue StandardError => e
      puts "✗ ERROR: #{e.message}"
    end

    # Up Bank API check (connectivity only, no auth)
    print "Up Bank API: "
    begin
      start_time = Time.current
      response = HTTParty.get(
        "https://api.up.com.au/api/v1",
        timeout: 5
      )
      response_time = ((Time.current - start_time) * 1000).round(2)
      # 401 is expected without auth, but means API is reachable
      if response.code == 401 || response.success?
        puts "✓ OK (#{response_time}ms, HTTP #{response.code})"
      else
        puts "⚠ WARNING: HTTP #{response.code}"
      end
    rescue StandardError => e
      puts "✗ ERROR: #{e.message}"
    end

    puts ""
    puts "=== End Health Check ==="
  end
end
