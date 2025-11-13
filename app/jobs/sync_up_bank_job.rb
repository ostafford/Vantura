class SyncUpBankJob < ApplicationJob
  queue_as :default

  # Retry on network errors or API rate limits
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  # Discard job if user is deleted
  discard_on ActiveRecord::RecordNotFound

  def perform(user_id)
    user = User.find(user_id)

    # Use Rails.error.handle to capture sync errors with context
    result = Rails.error.handle(
      StandardError,
      context: {
        user_id: user.id,
        account_count: user.accounts.count,
        action: "background_sync",
        job_id: job_id
      },
      fallback: -> { { success: false, error: "An unexpected error occurred during sync" } }
    ) do
      UpBank::SyncService.call(user)
    end

    # Broadcast completion notification to user via Turbo Streams
    if result && result[:success]
      # Invalidate dashboard cache for all user accounts
      user.accounts.each do |account|
        cache_key_pattern = "dashboard_stats_#{account.id}_*"
        Rails.cache.delete_matched(cache_key_pattern)
      end

      # Broadcast dashboard updates for each account
      user.accounts.each do |account|
        DashboardBroadcastService.call(account)
      end

      # Broadcast success notification to user's browser
      Turbo::StreamsChannel.broadcast_append_to(
        user,
        target: "app-sync-notification-container",
        partial: "shared/sync_complete_notification",
        locals: {
          new_transactions: result[:new_transactions],
          accounts: result[:accounts]
        }
      )

      Rails.logger.info "[SYNC] Background sync completed successfully for user #{user.id}: #{result[:new_transactions]} new transactions"
    else
      # Broadcast error notification
      Turbo::StreamsChannel.broadcast_append_to(
        user,
        target: "app-sync-notification-container",
        html: <<~HTML
          <div class="fixed top-4 right-4 bg-white dark:bg-gray-800 rounded-lg shadow-xl border-2 border-red-500 dark:border-red-400 p-4 min-w-[320px] z-50"
               data-controller="notification">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 bg-red-100 dark:bg-red-900/30 rounded-full flex items-center justify-center">
                <svg class="w-6 h-6 text-red-600 dark:text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                </svg>
              </div>
              <div class="flex-1">
                <p class="text-sm font-semibold text-gray-900 dark:text-white">Sync Failed</p>
                <p class="text-xs text-gray-600 dark:text-gray-400 mt-1">#{result[:error] || 'Please try again later'}</p>
              </div>
              <button type="button" data-action="click->notification#dismiss" class="text-gray-400 hover:text-gray-600">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                </svg>
              </button>
            </div>
          </div>
        HTML
      )

      Rails.logger.error "[SYNC] Background sync failed for user #{user.id}: #{result[:error]}"
    end
  end
end
