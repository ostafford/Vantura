class DashboardController < ApplicationController
  include AccountLoadable

  def index
    load_account_or_return
    return unless @account
    cache_key = "dashboard_stats_#{@account.id}_#{Date.today.strftime('%Y-%m-%d')}"
    stats = Rails.cache.fetch(cache_key, expires_in: 1.hour) { DashboardStatsCalculator.call(@account) }
    assign_dashboard_variables(stats)
    @sync_result = session.delete(:sync_result)
  end

  def get_current_week_transactions
    week_start = Date.today.beginning_of_week(:monday)
    week_end = Date.today.end_of_week(:monday)
    @account.transactions.where(transaction_date: week_start..week_end).includes(:recurring_transaction).order(transaction_date: :desc, id: :desc)
  end
  private :get_current_week_transactions

  def assign_dashboard_variables(stats)
    @current_date, @recent_transactions = stats[:current_date], get_current_week_transactions
    @expense_count, @expense_total, @income_count, @income_total = stats.values_at(:expense_count, :expense_total, :income_count, :income_total)
    @end_of_month_balance, @top_expense_merchants, @top_income_merchants = stats.values_at(:end_of_month_balance, :top_expense_merchants, :top_income_merchants)
    upcoming = RecurringTransactionsService.upcoming(@account, Date.today.end_of_month)
    @upcoming_recurring_expenses, @upcoming_recurring_income = upcoming.values_at(:expenses, :income)
    @upcoming_recurring_total = upcoming[:expense_total] + upcoming[:income_total]
  end
  private :assign_dashboard_variables

  def sync
    return redirect_to settings_path, alert: "Please configure your Up Bank token first." unless Current.user.up_bank_token.present?
    SyncUpBankJob.perform_later(Current.user.id)
    redirect_to root_path, notice: "🔄 Sync started! Your dashboard will update automatically when complete."
  end
end
