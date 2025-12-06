class ProcessUpWebhookJob < ApplicationJob
  queue_as :default

  # Large transaction threshold in cents ($1000 = 100,000 cents)
  LARGE_TRANSACTION_THRESHOLD_CENTS = 100_000

  # Discard job if webhook_event or user was deleted before job runs
  # This happens when GlobalID can't deserialize the record
  discard_on ActiveJob::DeserializationError

  # Retry strategy: polynomially_longer provides a more gradual backoff than exponentially_longer
  # This is better for API rate limits and reduces server load spikes
  # Reference: https://guides.rubyonrails.org/active_job_basics.html
  retry_on Net::ReadTimeout, wait: :polynomially_longer, attempts: 3
  retry_on Net::OpenTimeout, wait: :polynomially_longer, attempts: 3
  retry_on Timeout::Error, wait: :polynomially_longer, attempts: 3

  # Uses GlobalID to automatically serialize/deserialize the webhook_event object
  # If the record is deleted, ActiveJob::DeserializationError will be raised
  # and handled by the discard_on configuration above
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
  rescue => e
    # Reload webhook_event in case it was modified during processing
    webhook_event.reload if webhook_event.persisted?
    webhook_event&.mark_as_failed!(e.message)
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
    transaction = Transaction.find_or_create_from_up_data(transaction_data, user, account)

    # Check if transaction is large and create notification
    if transaction.amount_cents.abs >= LARGE_TRANSACTION_THRESHOLD_CENTS
      Notification.create_large_transaction_notification(
        user,
        transaction,
        threshold_cents: LARGE_TRANSACTION_THRESHOLD_CENTS
      )
    end

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
