class SyncUpBankDataJob < ApplicationJob
  queue_as :default

  # Retry strategy: polynomially_longer provides a more gradual backoff than exponentially_longer
  # This is better for API rate limits and reduces server load spikes
  # Reference: https://guides.rubyonrails.org/active_job_basics.html
  retry_on ActiveRecord::RecordNotFound, wait: :polynomially_longer, attempts: 3
  retry_on Net::TimeoutError, wait: :polynomially_longer, attempts: 3
  retry_on Faraday::TimeoutError, wait: :polynomially_longer, attempts: 3

  # Uses GlobalID to automatically serialize/deserialize the user object
  # If the user is deleted, ActiveJob::DeserializationError will be raised
  # and handled by ApplicationJob's discard_on configuration
  def perform(user)
    service = UpBankApiService.new(user)
    service.sync_all_data

    # Update sync timestamp
    user.update!(last_synced_at: Time.current)

    # Invalidate cache after sync
    Rails.cache.delete("user/#{user.id}/accounts")
    Rails.cache.delete("user/#{user.id}/balance")

    # Broadcast updates
    broadcast_dashboard_update(user)
  rescue ActiveRecord::RecordNotFound => e
    # User was deleted, discard silently
    Rails.logger.warn "User not found, discarding sync job: #{e.message}"
    raise
  rescue => e
    Rails.logger.error "Sync failed for user #{user.id}: #{e.message}"
    raise
  end

  private

  def broadcast_dashboard_update(user)
    Turbo::StreamsChannel.broadcast_update_to(
      "user_#{user.id}_dashboard",
      target: "balance_cards",
      partial: "dashboard/balance_cards",
      locals: { user: user }
    )
  rescue => e
    Rails.logger.error "Failed to broadcast update: #{e.message}"
  end
end
