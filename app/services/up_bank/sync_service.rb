module UpBank
  class SyncService < ApplicationService
    def initialize(account_id: nil)
      @account_id = account_id
      @client = UpBank::Client.call
    end

    def call
      if @account_id
        sync_single_account(@account_id)
      else
        sync_all_accounts
      end
    end

    private

    def sync_all_accounts
      Rails.logger.info "Starting sync of all Up Bank accounts..."

      response = @client.accounts
      synced_accounts = []

      response[:data].each do |account_data|
        account = sync_account(account_data)
        sync_transactions_for_account(account)
        synced_accounts << account
      end

      Rails.logger.info "Sync completed: #{synced_accounts.count} accounts synced"
      synced_accounts
    end

    def sync_single_account(up_account_id)
      Rails.logger.info "Starting sync for account: #{up_account_id}"

      response = @client.account(up_account_id)
      account = sync_account(response[:data])
      sync_transactions_for_account(account)

      Rails.logger.info "Sync completed for account: #{account.display_name}"
      account
    end

    def sync_account(account_data)
      attrs = account_data[:attributes]

      account = Account.find_or_initialize_by(up_account_id: account_data[:id])

      account.assign_attributes(
        display_name: attrs[:displayName],
        account_type: attrs[:accountType],
        current_balance: attrs[:balance][:value].to_f,
        last_synced_at: Time.current
      )

      account.save!
      Rails.logger.info "  ✓ Account synced: #{account.display_name} ($#{account.current_balance})"

      account
    end

    def sync_transactions_for_account(account)
      Rails.logger.info "  Syncing transactions for: #{account.display_name}"

      # Fetch transactions from Up Bank
      # We'll fetch the most recent 100 transactions
      response = @client.account_transactions(
        account.up_account_id,
        { 'page[size]' => 100 }
      )

      new_count = 0
      updated_count = 0

      response[:data].each do |txn_data|
        transaction = sync_transaction(account, txn_data)
        if transaction.previously_new_record?
          new_count += 1
        else
          updated_count += 1
        end
      end

      Rails.logger.info "  ✓ Transactions synced: #{new_count} new, #{updated_count} updated"

      { new: new_count, updated: updated_count }
    end

    def sync_transaction(account, txn_data)
      attrs = txn_data[:attributes]

      # Find or create transaction by Up transaction ID
      transaction = account.transactions.find_or_initialize_by(
        up_transaction_id: txn_data[:id]
      )

      # Map Up Bank status to our status
      status = map_status(attrs[:status])

      # Extract category
      category = txn_data.dig(:relationships, :category, :data, :id) || 'uncategorized'

      transaction.assign_attributes(
        description: attrs[:description],
        merchant: extract_merchant(attrs),
        amount: attrs[:amount][:value].to_f,
        category: category,
        transaction_date: Date.parse(attrs[:createdAt]),
        status: status,
        is_hypothetical: false,
        settled_at: attrs[:settledAt] ? Time.parse(attrs[:settledAt]) : nil
      )

      transaction.save!
      transaction
    end

    def map_status(up_status)
      case up_status
      when 'HELD'
        'HELD'
      when 'SETTLED'
        'SETTLED'
      else
        'SETTLED'
      end
    end

    def extract_merchant(attrs)
      # Try to get merchant from description, fallback to rawText
      attrs[:description] || attrs[:rawText] || 'Unknown'
    end
  end
end
