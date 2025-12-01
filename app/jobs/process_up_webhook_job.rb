class ProcessUpWebhookJob < ApplicationJob
  queue_as :default

  retry_on ActiveRecord::RecordNotFound, wait: :exponentially_longer, attempts: 3
  retry_on Net::TimeoutError, wait: :exponentially_longer, attempts: 3
  retry_on Faraday::TimeoutError, wait: :exponentially_longer, attempts: 3

  def perform(webhook_event)
    payload = webhook_event.payload

    event_type = payload.dig("data", "attributes", "eventType")

    case event_type
    when "TRANSACTION_CREATED", "TRANSACTION_SETTLED"
      process_transaction_event(payload, webhook_event.user)
    when "TRANSACTION_DELETED"
      process_transaction_deleted(payload, webhook_event.user)
    when "PING"
      # Just acknowledge
      Rails.logger.info "Webhook ping received"
    else
      Rails.logger.warn "Unknown event type: #{event_type}"
    end

    webhook_event.mark_as_processed!
  rescue ActiveRecord::RecordNotFound => e
    # Record was deleted, discard silently
    Rails.logger.warn "Webhook event not found, discarding: #{e.message}"
    raise
  rescue => e
    webhook_event.mark_as_failed!(e.message)
    Rails.logger.error "Webhook processing failed: #{e.message}"
    raise
  end

  private

  def process_transaction_event(payload, user)
    transaction_link = payload.dig("data", "relationships", "transaction", "links", "related")
    return unless transaction_link

    # Fetch full transaction data from Up API
    transaction_id = transaction_link.split("/").last
    service = UpBankApiService.new(user)
    transaction_data = service.fetch_transaction(transaction_id)

    # Find or create account
    account_up_id = transaction_data.dig("relationships", "account", "data", "id")
    account = user.accounts.find_by!(up_id: account_up_id)

    # Create or update transaction
    Transaction.find_or_create_from_up_data(transaction_data, user, account)

    # Broadcast update via Turbo Streams
    broadcast_dashboard_update(user)
  end

  def process_transaction_deleted(payload, user)
    transaction_up_id = payload.dig("data", "relationships", "transaction", "data", "id")
    transaction = user.transactions.find_by(up_id: transaction_up_id)
    transaction&.destroy
  end

  def broadcast_dashboard_update(user)
    Turbo::StreamsChannel.broadcast_update_to(
      "user_#{user.id}_dashboard",
      target: "recent_transactions",
      partial: "dashboard/recent_transactions",
      locals: { user: user }
    )
  rescue => e
    Rails.logger.error "Failed to broadcast update: #{e.message}"
  end
end
