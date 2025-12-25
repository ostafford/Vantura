module UpApi
  class TransactionsSync
    def initialize(user, account = nil)
      @user = user
      @account = account
      @client = Client.new(user.up_pat)
      @synced_count = 0
      @updated_count = 0
      @created_count = 0
    end

    def sync_all(since: nil, until_date: nil)
      since ||= determine_since_date

      params = build_params(since, until_date)
      sync_with_pagination(params)

      {
        synced: @synced_count,
        created: @created_count,
        updated: @updated_count
      }
    end

    private

    def determine_since_date
      # Get most recent transaction date, or default to 12 months ago
      most_recent = @user.transactions.maximum(:up_created_at)
      most_recent || 12.months.ago
    end

    def build_params(since, until_date)
      params = {
        "filter[since]" => since.iso8601,
        "page[size]" => 100 # Maximum page size
      }
      params["filter[until]"] = until_date.iso8601 if until_date
      params
    end

    def sync_with_pagination(params)
      next_cursor = nil

      loop do
        params["page[after]"] = next_cursor if next_cursor

        response = fetch_page(params)
        break unless response

        process_page(response)

        next_cursor = extract_next_cursor(response)
        break unless next_cursor

        # Rate limit protection
        sleep(0.5) if @synced_count % 100 == 0
      end
    end

    def fetch_page(params)
      @client.transactions(params)
    rescue UpApi::RateLimitError => e
      handle_rate_limit(e)
      retry
    end

    def process_page(response)
      transactions_data = response["data"] || []

      transactions_data.each do |transaction_data|
        process_transaction(transaction_data)
        @synced_count += 1
      end
    end

    def process_transaction(transaction_data)
      up_id = transaction_data["id"]
      transaction = @user.transactions.find_or_initialize_by(up_id: up_id)

      was_new = transaction.new_record?

      update_transaction_attributes(transaction, transaction_data)
      transaction.save!

      if was_new
        @created_count += 1
      else
        @updated_count += 1
      end

      sync_transaction_relationships(transaction, transaction_data)
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to save transaction #{up_id}: #{e.message}"
      raise
    end

    def update_transaction_attributes(transaction, data)
      attributes = data["attributes"]
      relationships = data["relationships"]

      # Find account
      account_up_id = relationships.dig("account", "data", "id")
      account = @account || @user.accounts.find_by!(up_id: account_up_id)

      # Parse money amount (Up API returns in base units, divide by 100)
      amount_data = attributes["amount"]
      amount = amount_data["valueInBaseUnits"].to_f / 100.0

      # Update attributes
      transaction.assign_attributes(
        account: account,
        status: attributes["status"],
        raw_text: attributes["rawText"],
        description: attributes["description"],
        message: attributes["message"],
        hold_info_is_cover: attributes.dig("holdInfo", "isCover") || false,
        amount: amount,
        currency_code: amount_data["currencyCode"],
        foreign_amount: attributes.dig("foreignAmount", "valueInBaseUnits"),
        foreign_currency_code: attributes.dig("foreignAmount", "currencyCode"),
        settled_at: parse_datetime(attributes["settledAt"]),
        up_created_at: parse_datetime(attributes["createdAt"])
      )
    end

    def sync_transaction_relationships(transaction, data)
      relationships = data["relationships"]

      # Sync categories
      category_data = relationships["category"]
      if category_data && category_data["data"]
        category_up_id = category_data["data"]["id"]
        category = Category.find_by(up_id: category_up_id)
        if category
          transaction.transaction_categories.find_or_create_by(category: category)
        end
      end

      # Sync tags
      tags_data = relationships["tags"]
      if tags_data && tags_data["data"]
        tags_data["data"].each do |tag_data|
          tag_name = tag_data["id"] # Up API uses tag name as ID
          tag = @user.tags.find_or_create_by(name: tag_name)
          transaction.transaction_tags.find_or_create_by(tag: tag)
        end
      end
    end

    def parse_datetime(datetime_string)
      return nil unless datetime_string
      Time.parse(datetime_string)
    rescue ArgumentError => e
      Rails.logger.warn "Failed to parse datetime #{datetime_string}: #{e.message}"
      nil
    end

    def extract_next_cursor(response)
      links = response["links"] || {}
      next_url = links["next"]
      return nil unless next_url

      uri = URI.parse(next_url)
      params = URI.decode_www_form(uri.query || "").to_h
      params["page[after]"]
    end

    def handle_rate_limit(error)
      wait_time = error.retry_after || 60
      Rails.logger.warn "Rate limit hit, waiting #{wait_time} seconds..."
      sleep(wait_time)
    end
  end
end

