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
