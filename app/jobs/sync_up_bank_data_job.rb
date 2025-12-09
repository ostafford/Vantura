require "redis"

class SyncUpBankDataJob < ApplicationJob
  queue_as :default

  # Retry strategy: polynomially_longer provides a more gradual backoff than exponentially_longer
  # This is better for API rate limits and reduces server load spikes
  # Reference: https://guides.rubyonrails.org/active_job_basics.html
  retry_on ActiveRecord::RecordNotFound, wait: :polynomially_longer, attempts: 3
  retry_on Net::ReadTimeout, wait: :polynomially_longer, attempts: 3
  retry_on Net::OpenTimeout, wait: :polynomially_longer, attempts: 3
  retry_on Timeout::Error, wait: :polynomially_longer, attempts: 3
  # Retry on rate limit errors with exponential backoff
  # Note: UpBankApiError is defined in UpBankApiService and will be autoloaded by Rails
  retry_on "UpBankApiError", wait: :exponentially_longer, attempts: 5 do |job, error|
    # Only retry if it's a rate limit error
    if error.message.include?("Rate limit exceeded")
      Rails.logger.warn "Retrying sync job for user #{job.arguments.first.id} after rate limit error"
    else
      # Don't retry other API errors
      raise error
    end
  end

  # Prevent duplicate sync jobs for the same user
  # Uses a Redis lock to ensure only one sync job runs per user at a time
  # This prevents rate limit issues from multiple simultaneous syncs
  before_perform :acquire_sync_lock
  after_perform :release_sync_lock

  # Custom exception for duplicate sync jobs
  class DuplicateSyncJobError < StandardError; end
  discard_on DuplicateSyncJobError

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

      # Step 3: Sync categories BEFORE transactions (required for category assignment)
      broadcast_progress_update(user, 40, "Fetching categories...")
      service.sync_categories
      broadcast_step_complete(user, "Categories processed")

      # Step 4: Sync transactions (with heartbeat updates)
      broadcast_progress_update(user, 50, "Retrieving transactions...")

      # Start heartbeat timer for long-running transaction sync
      # This ensures users see continuous activity during potentially long API calls
      # Uses "processing" state (nil percentage) to show animation without percentage changes
      @heartbeat_running = true
      heartbeat_thread = Thread.new do
        heartbeat_count = 0
        while @heartbeat_running
          sleep 3 # Send heartbeat every 3 seconds
          next unless @heartbeat_running # Check again after sleep

          heartbeat_count += 1
          elapsed_seconds = heartbeat_count * 3
          # Send nil percentage to indicate "processing" state with animation
          broadcast_progress_update(user, nil, "Processing transactions... (#{elapsed_seconds}s)")
        end
      rescue => e
        Rails.logger.error "Heartbeat thread error: #{e.message}"
      end

      begin
        service.sync_transactions
        transaction_count_after_sync = user.transactions.count
        new_transactions_count = transaction_count_after_sync - transaction_count_before
      ensure
        # Stop heartbeat when transaction sync completes
        @heartbeat_running = false
        if heartbeat_thread&.alive?
          heartbeat_thread.join(0.5) # Wait briefly for thread to finish
          heartbeat_thread.kill if heartbeat_thread.alive?
        end
      end

      broadcast_step_complete(user, "Retrieved #{new_transactions_count} transactions")

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

    # Broadcast completion toast
    broadcast_sync_completion_toast(user, success: true, transaction_count: new_transactions_count)
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

    # Broadcast failure toast
    broadcast_sync_completion_toast(user, success: false, error_message: e.message)

    raise
  end

  private

  # Acquire a lock to prevent multiple sync jobs for the same user
  # Lock expires after 30 minutes (syncs should never take that long)
  def acquire_sync_lock
    user = arguments.first
    lock_key = "sync_lock:user:#{user.id}"
    lock_timeout = 30.minutes

    redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
    
    # Try to acquire lock (returns true if acquired, false if already locked)
    lock_acquired = redis.set(lock_key, job_id, nx: true, ex: lock_timeout.to_i)
    
    unless lock_acquired
      # Another sync is already running for this user
      Rails.logger.info(
        "[SyncUpBankDataJob] Skipping duplicate sync job for user #{user.id}. " \
        "Another sync is already in progress."
      )
      # Raise custom exception that will be discarded (not retried)
      raise DuplicateSyncJobError, "Another sync job is already running for user #{user.id}"
    end
  rescue => e
    # If Redis fails, log but continue (better to allow sync than block it)
    Rails.logger.error(
      "[SyncUpBankDataJob] Failed to acquire sync lock for user #{arguments.first.id}: #{e.message}"
    )
    # Continue without lock - this is a safeguard, not a hard requirement
  end

  # Release the sync lock after job completes
  def release_sync_lock
    user = arguments.first
    lock_key = "sync_lock:user:#{user.id}"

    redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
    redis.del(lock_key)
  rescue => e
    # Log but don't raise - lock will expire naturally
    Rails.logger.warn(
      "[SyncUpBankDataJob] Failed to release sync lock for user #{user.id}: #{e.message}"
    )
  end

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
    # First, replace the completion-redirect content
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

    # Then, remove the hidden class to reveal it
    Turbo::StreamsChannel.broadcast_action_to(
      "user_#{user.id}_onboarding",
      action: "remove_class",
      target: "completion-redirect",
      classes: "hidden"
    )
  rescue => e
    Rails.logger.error "Failed to broadcast completion: #{e.message}"
  end

  def broadcast_dashboard_update(user)
    # Recalculate stats for the user
    stats = user.calculate_stats

    # Update stats cards
    Turbo::StreamsChannel.broadcast_replace_to(
      "user_#{user.id}_dashboard",
      target: "dashboard-stats",
      partial: "dashboard/stats",
      locals: { stats: stats }
    )

    # Update recent transactions list (Flow A: REPLACE entire list)
    # This ensures the list is always up-to-date with fresh data from the database
    recent_transactions = user.transactions.recent.limit(20)
    Turbo::StreamsChannel.broadcast_replace_to(
      "user_#{user.id}_dashboard",
      target: "recent-transactions",
      partial: "dashboard/recent_transactions",
      locals: { recent_transactions: recent_transactions }
    )
  rescue => e
    Rails.logger.error "Failed to broadcast update: #{e.message}"
  end

  def broadcast_sync_completion_toast(user, success:, transaction_count: 0, error_message: nil)
    if success
      message = if transaction_count > 0
        "Sync completed! #{transaction_count} new transaction#{transaction_count != 1 ? 's' : ''} synced."
      else
        "Sync completed! No new transactions found."
      end
      toast_type = "success"
    else
      message = "Sync failed: #{error_message || 'Unknown error'}"
      toast_type = "error"
    end

    # Use Turbo Streams to append a script tag that dispatches the toast event
    # Script tags execute immediately when added to the DOM via Turbo Streams
    Turbo::StreamsChannel.broadcast_append_to(
      "user_#{user.id}_dashboard",
      target: "toast-container",
      partial: "shared/sync_completion_toast_script",
      locals: { message: message, toast_type: toast_type }
    )
  rescue => e
    Rails.logger.error "Failed to broadcast sync completion toast: #{e.message}"
  end
end
