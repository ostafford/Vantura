module UpApi
  class AccountsSync
    def initialize(user)
      @user = user
      @client = Client.new(user.up_pat)
    end

    def sync
      Rails.logger.info "Starting accounts sync for user #{@user.id}"

      response = @client.accounts
      accounts_data = response["data"] || []

      accounts_data.each do |account_data|
        sync_account(account_data)
      end

      @user.update(last_synced_at: Time.current)
      Rails.logger.info "Accounts sync complete for user #{@user.id}: #{accounts_data.size} accounts"
    rescue UpApi::AuthenticationError => e
      Rails.logger.error "Authentication failed during accounts sync for user #{@user.id}: #{e.message}"
      raise
    rescue UpApi::ApiError => e
      Rails.logger.error "API error during accounts sync for user #{@user.id}: #{e.message}"
      raise
    end

    private

    def sync_account(account_data)
      account = @user.accounts.find_or_initialize_by(up_id: account_data["id"])

      attributes = account_data["attributes"]
      balance_data = attributes["balance"]

      account.assign_attributes(
        account_type: attributes["accountType"],
        ownership_type: attributes["ownershipType"],
        display_name: attributes["displayName"],
        balance: balance_data["valueInBaseUnits"].to_f / 100.0,
        currency_code: balance_data["currencyCode"],
        up_created_at: parse_datetime(attributes["createdAt"])
      )

      account.save!
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to save account #{account_data['id']}: #{e.message}"
      raise
    end

    def parse_datetime(datetime_string)
      return nil unless datetime_string
      Time.parse(datetime_string)
    rescue ArgumentError => e
      Rails.logger.warn "Failed to parse datetime #{datetime_string}: #{e.message}"
      nil
    end
  end
end

