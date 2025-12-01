# frozen_string_literal: true

# Rack Attack configuration for rate limiting
# See: https://github.com/rack/rack-attack
class Rack::Attack
  # Configure cache store for throttling
  # Uses the same cache store as Rails
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

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
      # Extract email from params
      req.params["user"]&.dig("email_address")&.to_s&.downcase&.gsub(/\s+/, "")
    end
  end

  # Custom response for throttled requests
  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"]
    now = match_data[:epoch_time]
    headers = {
      "X-RateLimit-Limit" => match_data[:limit].to_s,
      "X-RateLimit-Remaining" => "0",
      "X-RateLimit-Reset" => (now + (match_data[:period] - now % match_data[:period])).to_s,
      "Content-Type" => "application/json"
    }
    body = {
      error: "Rate limit exceeded. Please try again later.",
      retry_after: match_data[:period] - (now % match_data[:period])
    }.to_json
    [429, headers, [body]]
  end
end

