class DashboardController < ApplicationController
  include AccountLoadable

  def index
    load_account_or_return
    return unless @account

    # Calculate all dashboard stats using service with caching
    # Cache key includes account ID and current date for cache invalidation
    cache_key = "dashboard_stats_#{@account.id}_#{Date.today.strftime('%Y-%m-%d')}"
    stats = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      DashboardStatsCalculator.call(@account)
    end

    # Assign instance variables for view
    @current_date = stats[:current_date]

    # Fetch all transactions for the current week only (Monday to Sunday)
    @recent_transactions = get_current_week_transactions

    @expense_count = stats[:expense_count]
    @expense_total = stats[:expense_total]
    @income_count = stats[:income_count]
    @income_total = stats[:income_total]
    @end_of_month_balance = stats[:end_of_month_balance]
    @top_expense_merchants = stats[:top_expense_merchants]
    @top_income_merchants = stats[:top_income_merchants]

    # Get upcoming recurring transactions for the rest of the month
    @upcoming_recurring = get_upcoming_recurring_transactions
    @upcoming_recurring_expenses = @upcoming_recurring[:expenses]
    @upcoming_recurring_income = @upcoming_recurring[:income]
    @upcoming_recurring_total = @upcoming_recurring[:expense_total] + @upcoming_recurring[:income_total]

    # Check if there's a sync result to display (shown after redirect from sync action)
    @sync_result = session.delete(:sync_result)
  end

  def get_current_week_transactions
    # Get all transactions for the current week only (Monday to Sunday)
    week_start = Date.today.beginning_of_week(:monday)
    week_end = Date.today.end_of_week(:monday)

    @account.transactions
            .where(transaction_date: week_start..week_end)
            .includes(:recurring_transaction)
            .order(transaction_date: :desc, id: :desc)
  end
  private :get_current_week_transactions

  def get_upcoming_recurring_transactions
    # Get active recurring transactions that will occur before end of month
    end_of_month = Date.today.end_of_month

    upcoming = @account.recurring_transactions
                       .active
                       .where("next_occurrence_date <= ?", end_of_month)
                       .order(:next_occurrence_date)

    # Separate by type
    expenses = upcoming.select { |r| r.transaction_type_expense? }
    income = upcoming.select { |r| r.transaction_type_income? }

    {
      expenses: expenses,
      income: income,
      expense_total: expenses.sum { |r| r.amount.abs },
      income_total: income.sum { |r| r.amount }
    }
  end
  private :get_upcoming_recurring_transactions

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
