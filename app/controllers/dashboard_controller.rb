class DashboardController < ApplicationController
  include AccountLoadable

  def index
    load_account_or_return
    return unless @account
    @dashboard_data = build_dashboard_data
    @sync_result = session.delete(:sync_result)

    # Check for Up Bank notification from settings page
    if (up_bank_notification = session.delete(:up_bank_notification))
      flash[:notice] = up_bank_notification[:message]
      @up_bank_sync_result = up_bank_notification[:sync_result]
    end

    # Generate key insights for dashboard (2-3 top insights)
    insights_service = FinancialInsightsService.new(@account)
    @key_insights = insights_service.generate_key_insights(3)
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
