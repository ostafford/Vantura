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
