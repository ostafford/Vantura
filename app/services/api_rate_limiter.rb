# frozen_string_literal: true

require "redis"
require "securerandom"

# Rate limiter for external API calls using Redis sliding window
class ApiRateLimiter
  class RateLimitExceeded < StandardError
    attr_reader :retry_after

    def initialize(retry_after)
      @retry_after = retry_after
      super("Rate limit exceeded. Retry after #{retry_after} seconds")
    end
  end

  def initialize(limit:, period:, key_prefix:)
    @limit = limit
    @period = period
    @key_prefix = key_prefix
    @redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
  end

  def check!(identifier)
    key = "#{@key_prefix}:#{identifier}"
    now = Time.current.to_f

    # Remove old entries outside the window
    @redis.zremrangebyscore(key, 0, (now - @period).to_f)

    # Count current requests in window
    count = @redis.zcard(key)

    if count >= @limit
      # Find oldest entry to calculate retry_after
      oldest = @redis.zrange(key, 0, 0, with_scores: true).first
      retry_after = oldest ? (@period - (now - oldest[1])).ceil : @period
      raise RateLimitExceeded.new(retry_after)
    end

    # Add current request
    @redis.zadd(key, now, "#{now}-#{SecureRandom.hex(8)}")
    @redis.expire(key, @period.ceil)

    true
  end

  def remaining(identifier)
    key = "#{@key_prefix}:#{identifier}"
    now = Time.current.to_f

    @redis.zremrangebyscore(key, 0, (now - @period).to_f)
    count = @redis.zcard(key)

    [ @limit - count, 0 ].max
  end
end
