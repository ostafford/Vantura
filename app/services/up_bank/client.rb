require "httparty"

module UpBank
  class Client < ApplicationService
    include HTTParty
    base_uri "https://api.up.com.au/api/v1"

    def initialize(access_token)
      @access_token = access_token
      raise "Up Bank access token not provided" if @access_token.blank?
    end

    def call
      # This makes the service available for method calls
      self
    end

    # Ping endpoint - test authentication
    def ping
      get("/util/ping")
    end

    # Get all accounts
    def accounts
      get("/accounts")
    end

    # Get specific account
    def account(account_id)
      get("/accounts/#{account_id}")
    end

    # Get all transactions
    def transactions(params = {})
      get("/transactions", params)
    end

    # Get transactions for specific account
    def account_transactions(account_id, params = {})
      get("/accounts/#{account_id}/transactions", params)
    end

    # Follow pagination links until exhausted; returns array of page responses
    def paginate(initial_response)
      responses = [ initial_response ]
      next_link = initial_response.dig(:links, :next)
      while next_link
        response = follow(next_link)
        responses << response
        next_link = response.dig(:links, :next)
      end
      responses
    end

    private

    def get(endpoint, params = {})
      options = {
        headers: {
          "Authorization" => "Bearer #{@access_token}",
          "Content-Type" => "application/json"
        },
        query: params
      }

      response = self.class.get(endpoint, options)
      handle_response(response)
    end

    # Follow an absolute URL returned by Up's pagination links
    def follow(url)
      options = {
        headers: {
          "Authorization" => "Bearer #{@access_token}",
          "Content-Type" => "application/json"
        }
      }
      response = HTTParty.get(url, options)
      handle_response(response)
    end

    def handle_response(response)
      case response.code
      when 200..299
        JSON.parse(response.body, symbolize_names: true)
      when 401
        raise "Up Bank authentication failed - check your access token"
      when 429
        raise "Up Bank rate limit exceeded - please wait before retrying"
      else
        raise "Up Bank API error: #{response.code} - #{response.body}"
      end
    end
  end
end
