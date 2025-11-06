class DashboardController < ApplicationController
  include AccountLoadable

  def index
    load_account_or_return
    return unless @account
    @dashboard_data = build_dashboard_data
    @sync_result = session.delete(:sync_result)
  end

  def sync
    return redirect_to settings_path, alert: "Please configure your Up Bank token first." unless Current.user.up_bank_token.present?
    SyncUpBankJob.perform_later(Current.user.id)
    redirect_to root_path, notice: "Sync started! Your dashboard will update automatically when complete."
  end

  private

  def build_dashboard_data
    cache_key = "dashboard_stats_#{@account.id}_#{Date.today.strftime('%Y-%m-%d')}"
    stats = Rails.cache.fetch(cache_key, expires_in: 1.hour) { DashboardStatsCalculator.call(@account) }

    upcoming = RecurringTransactionsService.upcoming(@account, Date.today.end_of_month)

    stats.merge(
      recent_transactions: get_current_week_transactions,
      upcoming_recurring_expenses: upcoming[:expenses],
      upcoming_recurring_income: upcoming[:income],
      upcoming_recurring_total: upcoming[:expense_total] + upcoming[:income_total]
    )
  end

  def get_current_week_transactions
    week_start = Date.today.beginning_of_week(:monday)
    week_end = Date.today.end_of_week(:monday)
    @account.transactions
            .where(transaction_date: week_start..week_end)
            .includes(:recurring_transaction)
            .order(transaction_date: :desc, id: :desc)
  end
end
