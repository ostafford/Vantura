module UpBank
  class SyncService < ApplicationService
    def initialize(account_id: nil)
      @account_id = account_id
      @client = UpBank::Client.call
    end

    def call
      begin
        if @account_id
          sync_single_account(@account_id)
        else
          sync_all_accounts
        end
      rescue StandardError => e
        Rails.logger.error "Sync failed: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        { success: false, error: e.message, new_transactions: 0 }
      end
    end

    private

    def sync_all_accounts
      Rails.logger.info "Starting sync of all Up Bank accounts..."

      response = @client.accounts
      synced_accounts = []
      total_new_transactions = 0

      response[:data].each do |account_data|
        account = sync_account(account_data)
        result = sync_transactions_for_account(account)
        total_new_transactions += result[:new]
        synced_accounts << account
      end

      Rails.logger.info "Sync completed: #{synced_accounts.count} accounts synced"
      { success: true, new_transactions: total_new_transactions, accounts: synced_accounts }
    end

    def sync_single_account(up_account_id)
      Rails.logger.info "Starting sync for account: #{up_account_id}"

      response = @client.account(up_account_id)
      account = sync_account(response[:data])
      result = sync_transactions_for_account(account)

      Rails.logger.info "Sync completed for account: #{account.display_name}"
      { success: true, new_transactions: result[:new], account: account }
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

      # Fetch ALL transactions using pagination for full backfill
      first_page = @client.account_transactions(
        account.up_account_id,
        { "page[size]" => 100 }
      )
      pages = @client.paginate(first_page)

      new_count = 0
      updated_count = 0

      pages.each do |response|
        response[:data].each do |txn_data|
        transaction = sync_transaction(account, txn_data)
        if transaction.previously_new_record?
          new_count += 1
        else
          updated_count += 1
        end
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
      category = txn_data.dig(:relationships, :category, :data, :id) || "uncategorized"

      # Build transaction attributes
      transaction_attrs = {
        description: attrs[:description],
        merchant: extract_merchant(attrs),
        amount: attrs[:amount][:value].to_f,
        category: category,
        transaction_date: Date.parse(attrs[:createdAt]),
        status: status,
        is_hypothetical: false,
        settled_at: attrs[:settledAt] ? Time.parse(attrs[:settledAt]) : nil
      }

      # Check if this matches any recurring transaction pattern
      matching_recurring = find_matching_recurring_pattern(account, transaction_attrs)

      if matching_recurring
        # Find and remove the hypothetical transaction for this date
        hypothetical = account.transactions.hypothetical
                              .where(recurring_transaction_id: matching_recurring.id)
                              .where(transaction_date: transaction_attrs[:transaction_date])
                              .first

        hypothetical&.destroy

        # Link this real transaction to the recurring pattern
        transaction_attrs[:recurring_transaction_id] = matching_recurring.id

        # Update next occurrence date
        matching_recurring.update(next_occurrence_date: matching_recurring.calculate_next_occurrence)

        Rails.logger.info "  ✓ Matched transaction to recurring pattern: #{matching_recurring.description}"
      end

      transaction.assign_attributes(transaction_attrs)
      transaction.save!
      transaction
    end

    def find_matching_recurring_pattern(account, transaction_attrs)
      # Only check active recurring patterns
      account.recurring_transactions.active.find do |recurring|
        # Create a temporary transaction object for matching
        temp_transaction = Transaction.new(
          description: transaction_attrs[:description],
          amount: transaction_attrs[:amount],
          transaction_date: transaction_attrs[:transaction_date]
        )

        # Check if date is within expected window (±3 days)
        date_match = (temp_transaction.transaction_date - recurring.next_occurrence_date).abs <= 3

        date_match && recurring.matches_transaction?(temp_transaction)
      end
    end

    def map_status(up_status)
      case up_status
      when "HELD"
        "HELD"
      when "SETTLED"
        "SETTLED"
      else
        "SETTLED"
      end
    end

    def extract_merchant(attrs)
      # Try to get merchant from description, fallback to rawText
      attrs[:description] || attrs[:rawText] || "Unknown"
    end
  end
end
