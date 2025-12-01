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
    # TODO: Implement proper user identification
    # Options:
    # 1. Store webhook_id -> user_id mapping when creating webhook
    # 2. Extract user from webhook payload if available
    # 3. Use single user for MVP
    User.first # Temporary - implement proper logic
  end
end
