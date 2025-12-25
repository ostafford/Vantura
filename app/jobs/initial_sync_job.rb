class InitialSyncJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    Rails.logger.info "=== InitialSyncJob#perform STARTED ==="
    Rails.logger.info "job_id: #{job_id rescue 'N/A'}"
    Rails.logger.info "user_id: #{user_id}"
    
    user = User.find(user_id)
    Rails.logger.info "user found: #{user.id}, last_synced_at before: #{user.last_synced_at.inspect}"

    unless user.up_pat_configured?
      Rails.logger.warn "InitialSyncJob: User #{user_id} does not have PAT configured, skipping"
      return
    end

    Rails.logger.info "InitialSyncJob: Starting initial sync for user #{user_id}"

    start_time = Time.current

    # Step 1: Sync accounts (synchronous to ensure it completes first)
    Rails.logger.info "InitialSyncJob: Step 1/3 - Syncing accounts for user #{user_id}"
    SyncAccountsJob.perform_now(user_id)

    # Step 2: Sync categories (only if not already synced)
    unless Category.exists?
      Rails.logger.info "InitialSyncJob: Step 2/3 - Syncing categories (triggered by user #{user_id})"
      SyncCategoriesJob.perform_now(user_id)
    else
      Rails.logger.info "InitialSyncJob: Step 2/3 - Categories already exist, skipping"
    end

    # Step 3: Sync transactions (last 12 months)
    Rails.logger.info "InitialSyncJob: Step 3/3 - Syncing transactions for user #{user_id}"
    SyncTransactionsJob.perform_now(user_id)

    # Step 4: Update sync timestamp
    Rails.logger.info "InitialSyncJob: About to update last_synced_at for user #{user_id}"
    update_result = user.update(last_synced_at: Time.current)
    Rails.logger.info "InitialSyncJob: Update result: #{update_result.inspect}"
    user.reload
    Rails.logger.info "InitialSyncJob: last_synced_at after update: #{user.last_synced_at.inspect}"
    duration = Time.current - start_time

    Rails.logger.info "=== InitialSyncJob#perform COMPLETED ==="
    Rails.logger.info "InitialSyncJob: Completed initial sync for user #{user_id} in #{duration.round(2)}s"
  rescue UpApi::AuthenticationError => e
    Rails.logger.error "InitialSyncJob: Authentication failed for user #{user_id}: #{e.message}"
    raise # Will be discarded by ApplicationJob
  rescue UpApi::ApiError => e
    Rails.logger.error "InitialSyncJob: API error for user #{user_id}: #{e.message}"
    raise # Will be retried by ApplicationJob
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "InitialSyncJob: User #{user_id} not found: #{e.message}"
    # Don't retry if user doesn't exist
  end
end

