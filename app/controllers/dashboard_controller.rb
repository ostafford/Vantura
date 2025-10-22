class DashboardController < ApplicationController
  include AccountLoadable

  def index
    load_account_or_return
    return unless @account

    # Calculate all dashboard stats using service
    stats = DashboardStatsCalculator.call(@account)

    # Assign instance variables for view
    @current_date = stats[:current_date]
    @recent_transactions = stats[:recent_transactions]
    @expense_count = stats[:expense_count]
    @expense_total = stats[:expense_total]
    @income_count = stats[:income_count]
    @income_total = stats[:income_total]
    @end_of_month_balance = stats[:end_of_month_balance]

    # Check if there's a sync result to display (shown after redirect from sync action)
    @sync_result = session.delete(:sync_result)
  end

  def sync
    unless Current.user.up_bank_token.present?
      redirect_to settings_path, alert: "Please configure your Up Bank token first."
      return
    end

    # Enqueue background sync job
    SyncUpBankJob.perform_later(Current.user.id)

    # Redirect and show sync started notification
    redirect_to root_path, notice: "🔄 Sync started! Your dashboard will update automatically when complete."
  end
end
