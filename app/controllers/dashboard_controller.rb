class DashboardController < ApplicationController
  before_action :authenticate_user!
  after_action :trigger_sync_if_needed, only: [ :index ]

  def index
    @accounts = current_user.accounts.includes(:transactions)
    @recent_transactions = current_user.transactions.recent.limit(10)
    @balance = current_user.accounts.sum(&:balance)
  end

  def sync
    return head :unauthorized unless current_user.has_up_bank_token?

    SyncUpBankDataJob.perform_later(current_user)
    redirect_to dashboard_path, notice: "Sync started"
  end

  private

  def trigger_sync_if_needed
    return if session[:last_sync] && session[:last_sync] > 5.minutes.ago
    return unless current_user.has_up_bank_token?

    SyncUpBankDataJob.perform_later(current_user)
    session[:last_sync] = Time.current
  end
end
