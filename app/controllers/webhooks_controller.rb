class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_webhook_signature

  def up
    # Store raw payload for audit
    webhook_event = WebhookEvent.create!(
      user: find_user_from_payload,
      event_type: payload["data"]["attributes"]["eventType"],
      payload: payload
    )

    # Process in background
    ProcessUpWebhookJob.perform_later(webhook_event)

    head :ok
  rescue => e
    Rails.logger.error "Webhook error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    head :ok # Always return 200 to Up Bank
  end

  private

  def payload
    @payload ||= JSON.parse(request.raw_post)
  end

  def verify_webhook_signature
    received_signature = request.headers["X-Up-Authenticity-Signature"]
    secret_key = ENV.fetch("UP_BANK_WEBHOOK_SECRET_KEY")

    unless received_signature.present?
      raise SecurityError, "Invalid webhook signature"
    end

    computed_signature = OpenSSL::HMAC.hexdigest(
      "SHA256",
      secret_key,
      request.raw_post
    )

    unless Rack::Utils.secure_compare(received_signature, computed_signature)
      raise SecurityError, "Invalid webhook signature"
    end
  end

  def find_user_from_payload
    event_type = payload.dig("data", "attributes", "eventType")
    
    # For PING events, we don't have transaction data, so use fallback
    if event_type == "PING"
      return find_user_fallback
    end
    
    # For transaction events, try to identify user from transaction
    transaction_up_id = extract_transaction_id_from_payload
    
    if transaction_up_id
      # Check if transaction already exists in database
      transaction = Transaction.find_by(up_id: transaction_up_id)
      if transaction
        Rails.logger.info "Webhook: Found existing transaction #{transaction_up_id}, user: #{transaction.user_id}"
        return transaction.user
      end
      
      # Transaction doesn't exist yet - we'll need to fetch it
      # ProcessUpWebhookJob will handle fetching and can verify the user
      # For now, use fallback which will work for MVP (single user or user with token)
      Rails.logger.info "Webhook: Transaction #{transaction_up_id} not found in DB, using fallback user identification"
    end
    
    find_user_fallback
  end
  
  def extract_transaction_id_from_payload
    # Try to get transaction ID from relationships
    transaction_link = payload.dig("data", "relationships", "transaction", "links", "related")
    return nil unless transaction_link
    
    # Extract transaction ID from URL like: https://api.up.com.au/api/v1/transactions/abc123
    transaction_link.split("/").last
  rescue => e
    Rails.logger.error "Webhook: Error extracting transaction ID: #{e.message}"
    nil
  end
  
  def find_user_fallback
    # Fallback strategy for user identification:
    # 1. If only one user exists, use that (common in development/MVP)
    # 2. If multiple users, try to find one with an Up Bank token
    # 3. Otherwise, raise error in production, use first in development
    
    if User.count == 1
      user = User.first
      Rails.logger.info "Webhook: Using single user (ID: #{user.id})"
      return user
    end
    
    # Try to find a user with Up Bank token (most likely to receive webhooks)
    user_with_token = User.where.not(up_bank_token_encrypted: nil).first
    if user_with_token
      Rails.logger.info "Webhook: Using user with token (ID: #{user_with_token.id})"
      return user_with_token
    end
    
    # Development fallback
    if Rails.env.development? || Rails.env.test?
      user = User.first
      Rails.logger.warn "Webhook: Using User.first as fallback (development/test mode, ID: #{user&.id})"
      return user
    end
    
    # Production: raise error if we can't identify user
    Rails.logger.error "Webhook: Unable to identify user from payload. User count: #{User.count}"
    raise SecurityError, "Unable to identify user from webhook payload. Ensure at least one user has an Up Bank token configured."
  end
end
