require "faraday"
require_relative "../../../lib/up_api/errors"

module UpApi
  class Client
    BASE_URL = "https://api.up.com.au/api/v1".freeze

    def initialize(personal_access_token)
      @token = personal_access_token
      @connection = build_connection
    end

    # Health check endpoint
    def ping
      get("util/ping")
    end

    # List all accounts
    def accounts
      get("accounts")
    end

    # Get specific account
    def account(id)
      get("accounts/#{id}")
    end

    # List transactions with optional filters
    # @param params [Hash] Query parameters (filter[since], filter[until], page[size], page[after])
    def transactions(params = {})
      get("transactions", params)
    end

    # Get specific transaction
    def transaction(id)
      get("transactions/#{id}")
    end

    # List all categories
    def categories
      get("categories")
    end

    # Get specific category
    def category(id)
      get("categories/#{id}")
    end

    private

    def build_connection
      Faraday.new(url: BASE_URL) do |conn|
        conn.request :json
        conn.response :json, content_type: /\bjson$/
        conn.adapter Faraday.default_adapter
        conn.headers["Authorization"] = "Bearer #{@token}"
        conn.headers["Content-Type"] = "application/json"
        conn.headers["User-Agent"] = "Vantura/1.0"
      end
    end

    def get(path, params = {})
      response = @connection.get(path, params)
      handle_response(response)
    rescue Faraday::Error => e
      handle_error(e)
    end

    def handle_response(response)
      # Check rate limit headers
      remaining = response.headers["X-RateLimit-Remaining"]&.to_i
      limit = response.headers["X-RateLimit-Limit"]&.to_i

      if remaining && remaining < 10
        Rails.logger.warn "Up API rate limit low: #{remaining}/#{limit} remaining"
      end

      case response.status
      when 200..299
        response.body
      when 401
        raise AuthenticationError.new("Invalid or expired token", 401, response.body)
      when 404
        raise NotFoundError.new("Resource not found", 404, response.body)
      when 429
        retry_after = response.headers["Retry-After"]&.to_i || 60
        raise RateLimitError.new(
          "Rate limit exceeded. Retry after #{retry_after} seconds",
          429,
          response.body,
          retry_after: retry_after
        )
      when 500..599
        raise ServerError.new("Server error: #{response.status}", response.status, response.body)
      else
        raise ApiError.new("API error: #{response.status}", response.status, response.body)
      end
    end

    def handle_error(error)
      Rails.logger.error "Up API network error: #{error.message}"
      raise ApiError.new("Network error: #{error.message}")
    end
  end
end

