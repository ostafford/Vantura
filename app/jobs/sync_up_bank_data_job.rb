class SyncUpBankDataJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    service = UpBankApiService.new(user)
    service.sync_all_data

    # Broadcast updates
    broadcast_dashboard_update(user)
  rescue => e
    Rails.logger.error "Sync failed for user #{user_id}: #{e.message}"
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
