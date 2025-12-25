class SyncTransactionsJob < ApplicationJob
  queue_as :default

  def perform(user_id, account_id = nil)
    user = User.find(user_id)

    unless user.up_pat_configured?
      Rails.logger.warn "SyncTransactionsJob: User #{user_id} does not have PAT configured, skipping"
      return
    end

    account = account_id ? user.accounts.find(account_id) : nil
    account_info = account ? "account #{account_id}" : "all accounts"

    Rails.logger.info "SyncTransactionsJob: Starting transactions sync for user #{user_id}, #{account_info}"

    start_time = Time.current
    sync_service = UpApi::TransactionsSync.new(user, account)
    result = sync_service.sync_all
    duration = Time.current - start_time

    Rails.logger.info "SyncTransactionsJob: Completed transactions sync for user #{user_id}, #{account_info} in #{duration.round(2)}s - " \
                      "Synced: #{result[:synced]}, Created: #{result[:created]}, Updated: #{result[:updated]}"
  rescue UpApi::AuthenticationError => e
    Rails.logger.error "SyncTransactionsJob: Authentication failed for user #{user_id}: #{e.message}"
    raise # Will be discarded by ApplicationJob
  rescue UpApi::ApiError => e
    Rails.logger.error "SyncTransactionsJob: API error for user #{user_id}: #{e.message}"
    raise # Will be retried by ApplicationJob
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "SyncTransactionsJob: User #{user_id} or account #{account_id} not found: #{e.message}"
    # Don't retry if user/account doesn't exist
  end
end

