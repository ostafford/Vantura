class CalendarController < ApplicationController
  include AccountLoadable
  include DateParseable

  def index
    parse_month_params
    @view = params[:view] || session[:calendar_view] || "month"
    session[:calendar_view] = @view
    load_account_or_return
    return unless @account
    data = CalendarDataService.call(@account, params.slice(:year, :month, :day), @view)
    assign_calendar_variables(data)
    respond_to { |format| format.html; format.turbo_stream }
  end

  private

  def assign_calendar_variables(data)
    @date, @year, @month = data.values_at(:date, :year, :month)
    @current_date = @date
    @start_date, @end_date = data.values_at(:start_date, :end_date)
    @transactions, @transactions_by_date = data.values_at(:transactions, :transactions_by_date)
    @weeks, @week_days, @eow_amounts, @week_end_balance = data.values_at(:weeks, :week_days, :eow_amounts, :week_end_balance)
    @end_of_month_balance = data[:end_of_month_balance]
    stats = data[:calendar_stats]
    @hypothetical_income, @hypothetical_expenses = stats.values_at(:hypothetical_income, :hypothetical_expenses)
    @actual_income, @actual_expenses, @transaction_count = stats.values_at(:actual_income, :actual_expenses, :transaction_count)
    @month_day, @total_days, @progress_pct = stats.values_at(:month_day, :total_days, :progress_pct)
    @week_income, @week_expenses, @week_transaction_count = stats.values_at(:week_income, :week_expenses, :week_transaction_count)
    @week_total, @week_expense_count, @week_income_count = stats.values_at(:week_total, :week_expense_count, :week_income_count)
    @month_expense_count, @month_income_count = stats.values_at(:month_expense_count, :month_income_count)
    @top_expense_merchants, @top_income_merchants = stats.values_at(:top_expense_merchants, :top_income_merchants)
    @month_top_expense_merchants, @month_top_income_merchants = @top_expense_merchants, @top_income_merchants
    @week_top_expense_merchants, @week_top_income_merchants = @top_expense_merchants, @top_income_merchants

    # Extract spending velocity data (month view only)
    if @view == "month" && stats[:spending_velocity].present?
      velocity = stats[:spending_velocity]
      @spending_daily_rate = velocity[:daily_rate]
      @spending_projected_total = velocity[:projected_total]
      @spending_velocity_change_pct = velocity[:velocity_change_pct]
      @spending_rate = velocity[:spending_rate]
    else
      @spending_daily_rate = 0.0
      @spending_projected_total = 0.0
      @spending_velocity_change_pct = 0.0
      @spending_rate = 0.0
    end

    # Extract upcoming transactions data (month view only)
    if @view == "month" && data[:upcoming_transactions].present?
      upcoming = data[:upcoming_transactions]
      @upcoming_recurring_expenses = upcoming[:upcoming_recurring_expenses] || []
      @upcoming_recurring_income = upcoming[:upcoming_recurring_income] || []
      @upcoming_hypothetical_expenses = upcoming[:upcoming_hypothetical_expenses] || []
      @upcoming_hypothetical_income = upcoming[:upcoming_hypothetical_income] || []
    else
      @upcoming_recurring_expenses = []
      @upcoming_recurring_income = []
      @upcoming_hypothetical_expenses = []
      @upcoming_hypothetical_income = []
    end
  end

  def day_total(date)
    return 0 unless @transactions_by_date[date]
    @transactions_by_date[date].sum(&:amount)
  end
  helper_method :day_total

  def day_transactions(date)
    @transactions_by_date[date] || []
  end
  helper_method :day_transactions
end
