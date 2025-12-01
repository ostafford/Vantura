class SyncUpBankDataJob < ApplicationJob
  queue_as :default

  retry_on ActiveRecord::RecordNotFound, wait: :exponentially_longer, attempts: 3
  retry_on Net::TimeoutError, wait: :exponentially_longer, attempts: 3
  retry_on Faraday::TimeoutError, wait: :exponentially_longer, attempts: 3

  def perform(user)
    service = UpBankApiService.new(user)
    service.sync_all_data

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
