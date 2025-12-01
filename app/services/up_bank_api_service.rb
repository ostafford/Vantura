class UpBankApiService
  BASE_URL = "https://api.up.com.au/api/v1".freeze

  # Rate limit: 100 requests per minute per user
  RATE_LIMIT = 100
  RATE_PERIOD = 60.seconds

  def initialize(user)
    @user = user
    @token = user.up_bank_token
    raise ArgumentError, "User has no Up Bank token" unless @token

    @rate_limiter = ApiRateLimiter.new(
      limit: RATE_LIMIT,
      period: RATE_PERIOD,
      key_prefix: "up_bank_api"
    )
  end

  # Fetch all accounts
  def fetch_accounts
    response = get("/accounts")
    response["data"] || []
  end

  # Fetch all transactions (paginated)
  def fetch_all_transactions
    transactions = []
    page_token = nil

    loop do
      response = fetch_transactions(page_token)
      transactions.concat(response["data"] || [])

      page_token = extract_page_token(response.dig("links", "next"))
      break unless page_token
    end

    transactions
  end

  # Fetch single transaction
  def fetch_transaction(transaction_id)
    response = get("/transactions/#{transaction_id}")
    response["data"]
  end

  # Sync all data (accounts + transactions)
  def sync_all_data
    sync_accounts
    sync_transactions
  end

  # Sync accounts from API
  def sync_accounts
    accounts_data = fetch_accounts
    accounts_data.each do |account_data|
      account = @user.accounts.find_or_initialize_by(up_id: account_data["id"])
      account.assign_attributes(
        account_type: account_data.dig("attributes", "accountType"),
        display_name: account_data.dig("attributes", "displayName"),
        balance_cents: account_data.dig("attributes", "balance", "valueInBaseUnits"),
        balance_currency: "AUD"
      )
      account.save!
    end
  end

  # Sync transactions from API
  def sync_transactions
    transactions_data = fetch_all_transactions
    transactions_data.each do |transaction_data|
      account_up_id = transaction_data.dig("relationships", "account", "data", "id")
      account = @user.accounts.find_by!(up_id: account_up_id)
      Transaction.find_or_create_from_up_data(transaction_data, @user, account)
    end
  end

  private

  def get(endpoint)
    # Check rate limit before making request
    @rate_limiter.check!(@user.id)

    url = "#{BASE_URL}#{endpoint}"
    response = HTTParty.get(
      url,
      headers: headers,
      timeout: 30
    )

    raise UpBankApiError, "API Error: #{response.code}" unless response.success?

    JSON.parse(response.body)
  rescue ApiRateLimiter::RateLimitExceeded => e
    raise UpBankApiError, "Rate limit exceeded. Retry after #{e.retry_after} seconds"
  rescue JSON::ParserError => e
    raise UpBankApiError, "Failed to parse API response: #{e.message}"
  end

  def headers
    {
      "Authorization" => "Bearer #{@token}",
      "Content-Type" => "application/json"
    }
  end

  def fetch_transactions(page_token = nil)
    endpoint = "/transactions"
    endpoint += "?page[after]=#{page_token}" if page_token
    get(endpoint)
  end

  def extract_page_token(next_link)
    return nil unless next_link
    uri = URI.parse(next_link)
    params = URI.decode_www_form(uri.query || "").to_h
    params["page[after]"]
  end
end

class UpBankApiError < StandardError; end
