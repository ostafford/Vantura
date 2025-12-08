class SyncUpBankDataJob < ApplicationJob
  queue_as :default

  # Retry strategy: polynomially_longer provides a more gradual backoff than exponentially_longer
  # This is better for API rate limits and reduces server load spikes
  # Reference: https://guides.rubyonrails.org/active_job_basics.html
  retry_on ActiveRecord::RecordNotFound, wait: :polynomially_longer, attempts: 3
  retry_on Net::ReadTimeout, wait: :polynomially_longer, attempts: 3
  retry_on Net::OpenTimeout, wait: :polynomially_longer, attempts: 3
  retry_on Timeout::Error, wait: :polynomially_longer, attempts: 3

  # Uses GlobalID to automatically serialize/deserialize the user object
  # If the user is deleted, ActiveJob::DeserializationError will be raised
  # and handled by ApplicationJob's discard_on configuration
  def perform(user, broadcast_progress: false)
    # Track transaction count before sync
    transaction_count_before = user.transactions.count

    service = UpBankApiService.new(user)

    if broadcast_progress
      # Step 1: Connect to Up Bank
      broadcast_progress_update(user, 10, "Connecting to Up Bank...")
      
      # Step 2: Sync accounts
      broadcast_progress_update(user, 25, "Fetching accounts...")
      accounts = service.sync_accounts
      broadcast_step_complete(user, "Fetched #{accounts.count} accounts")
      
      # Step 3: Sync transactions
      broadcast_progress_update(user, 50, "Retrieving transactions...")
      service.sync_transactions
      transaction_count_after_sync = user.transactions.count
      new_transactions_count = transaction_count_after_sync - transaction_count_before
      broadcast_step_complete(user, "Retrieved #{new_transactions_count} transactions")
      
      # Step 4: Sync categories
      broadcast_progress_update(user, 75, "Processing categories...")
      service.sync_categories
      broadcast_step_complete(user, "Categories processed")
      
      # Step 5: Finalize
      broadcast_progress_update(user, 100, "Calculating analytics...")
      
      # Set final transaction count for completion broadcast
      transaction_count_after = transaction_count_after_sync
    else
      # Standard sync without progress updates
      service.sync_all_data
      # Calculate how many new transactions were synced
      transaction_count_after = user.transactions.count
      new_transactions_count = transaction_count_after - transaction_count_before
    end

    # Update sync timestamp
    user.update!(last_synced_at: Time.current)

    # Invalidate cache after sync
    Rails.cache.delete("user/#{user.id}/accounts")
    Rails.cache.delete("user/#{user.id}/balance")

    # Create success notification
    Notification.create_sync_notification(
      user,
      success: true,
      transaction_count: new_transactions_count
    )

    # Broadcast completion if in progress mode
    if broadcast_progress
      broadcast_completion(user, user.accounts.count, new_transactions_count)
    end

    # Broadcast updates
    broadcast_dashboard_update(user)
  rescue ActiveRecord::RecordNotFound => e
    # User was deleted, discard silently
    Rails.logger.warn "User not found, discarding sync job: #{e.message}"
    raise
  rescue => e
    Rails.logger.error "Sync failed for user #{user.id}: #{e.message}"

    # Create failure notification
    Notification.create_sync_notification(
      user,
      success: false,
      error_message: e.message
    )

    raise
  end

  private

  def broadcast_progress_update(user, percentage, message)
    Turbo::StreamsChannel.broadcast_replace_to(
      "user_#{user.id}_onboarding",
      target: "progress-bar",
      partial: "onboarding/progress_bar",
      locals: { percentage: percentage, message: message }
    )
  rescue => e
    Rails.logger.error "Failed to broadcast progress: #{e.message}"
  end

  def broadcast_step_complete(user, message)
    Turbo::StreamsChannel.broadcast_append_to(
      "user_#{user.id}_onboarding",
      target: "sync-steps",
      partial: "onboarding/sync_step",
      locals: { message: message, completed: true }
    )
  rescue => e
    Rails.logger.error "Failed to broadcast step: #{e.message}"
  end

  def broadcast_completion(user, accounts_count, transactions_count)
    Turbo::StreamsChannel.broadcast_replace_to(
      "user_#{user.id}_onboarding",
      target: "completion-redirect",
      partial: "onboarding/completion",
      locals: {
        accounts_count: accounts_count,
        transactions_count: transactions_count,
        categories_count: Category.count
      }
    )
  rescue => e
    Rails.logger.error "Failed to broadcast completion: #{e.message}"
  end

  def broadcast_dashboard_update(user)
    # Recalculate stats for the user
    stats = user.calculate_stats
    
    Turbo::StreamsChannel.broadcast_replace_to(
      "user_#{user.id}_dashboard",
      target: "dashboard-stats",
      partial: "dashboard/stats",
      locals: { stats: stats }
    )
  rescue => e
    Rails.logger.error "Failed to broadcast update: #{e.message}"
  end
end
