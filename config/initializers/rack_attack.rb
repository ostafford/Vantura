# frozen_string_literal: true

# Rack Attack configuration for rate limiting
# See: https://github.com/rack/rack-attack
class Rack::Attack
  # Use Redis for distributed rate limiting across multiple servers
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"),
    namespace: "rack_attack"
  )

  # Allow requests from localhost (useful for health checks)
  safelist("allow-localhost") do |req|
    req.ip == "127.0.0.1" || req.ip == "::1"
  end

  # Throttle webhook requests by IP address
  # Limit: 10 requests per minute per IP
  throttle("webhooks/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/webhooks")
  end

  # Throttle API requests by IP address
  # Limit: 100 requests per minute per IP
  throttle("api/ip", limit: 100, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/api")
  end

  # Throttle login attempts by email address
  # Limit: 5 attempts per 20 minutes per email
  throttle("logins/email", limit: 5, period: 20.minutes) do |req|
    if req.path == "/users/sign_in" && req.post?
      req.params.dig("user", "email_address")&.to_s&.downcase&.strip
    end
  end

  # Throttle by authenticated user
  throttle("authenticated/user", limit: 300, period: 5.minutes) do |req|
    req.env["warden"]&.user&.id if req.env["warden"]&.user
  end

  # Block suspicious requests
  blocklist("block-suspicious") do |req|
    # Block if user-agent is blank
    req.user_agent.blank? ||
    # Block known bad user agents
    req.user_agent =~ /curl|bot|crawler|spider/i
  end

  # Custom response for throttled requests
  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"]
    now = match_data[:epoch_time]

    headers = {
      "X-RateLimit-Limit" => match_data[:limit].to_s,
      "X-RateLimit-Remaining" => "0",
      "X-RateLimit-Reset" => (now + (match_data[:period] - now % match_data[:period])).to_s,
      "Content-Type" => "application/json",
      "Retry-After" => (match_data[:period] - (now % match_data[:period])).to_s
    }

    body = {
      error: "Rate limit exceeded. Please try again later.",
      retry_after: match_data[:period] - (now % match_data[:period])
    }.to_json

    [ 429, headers, [ body ] ]
  end

  # Log blocked requests in production
  ActiveSupport::Notifications.subscribe("rack.attack") do |name, start, finish, request_id, payload|
    req = payload[:request]

    if [ :throttle, :blocklist ].include?(payload[:request].env["rack.attack.match_type"])
      Rails.logger.warn "[Rack::Attack][#{payload[:request].env['rack.attack.match_type']}] " \
                        "IP: #{req.ip} Path: #{req.path} Matched: #{req.env['rack.attack.matched']}"
    end
  end
end
