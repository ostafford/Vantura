class DashboardController < ApplicationController
  before_action :authenticate_user!
  after_action :trigger_sync_if_needed, only: [ :index ]

  def index
    # Use Russian Doll caching
    @accounts = Rails.cache.fetch("user/#{current_user.id}/accounts", expires_in: 5.minutes) do
      current_user.accounts.to_a
    end

    # Paginate transactions instead of loading all
    # Pagy 4.3: Use :offset for standard pagination
    @pagy, @recent_transactions = pagy(:offset, current_user.transactions.recent, items: 20)

    # Calculate balance efficiently with caching
    @balance = Rails.cache.fetch("user/#{current_user.id}/balance", expires_in: 5.minutes) do
      current_user.accounts.sum(:balance_cents)
    end
  end

  def sync
    return head :unauthorized unless current_user.has_up_bank_token?

    # Invalidate cache before syncing
    Rails.cache.delete("user/#{current_user.id}/accounts")
    Rails.cache.delete("user/#{current_user.id}/balance")

    SyncUpBankDataJob.perform_later(current_user)
    redirect_to dashboard_path, notice: "Sync started"
  end

  private

  def trigger_sync_if_needed
    # Use database-backed throttling instead of session
    last_sync = current_user.webhook_events.maximum(:created_at)
    return if last_sync && last_sync > 5.minutes.ago
    return unless current_user.has_up_bank_token?

    SyncUpBankDataJob.perform_later(current_user)
  end
end
