module ChartDataHelper
  extend ActiveSupport::Concern

  private

  def prepare_income_vs_expenses_data(user)
    # Last 30 days
    start_date = 30.days.ago.beginning_of_day
    end_date = Time.current.end_of_day

    # Get daily data
    income_data = Transaction.time_series_by_day(
      user,
      start_date,
      end_date,
      type: :income
    )

    expense_data = Transaction.time_series_by_day(
      user,
      start_date,
      end_date,
      type: :expenses
    )

    # Format for Chartkick multiple series
    [
      {
        name: "Income",
        data: income_data.transform_values { |cents| cents / 100.0 }
      },
      {
        name: "Expenses",
        data: expense_data.transform_values { |cents| cents.abs / 100.0 }
      }
    ]
  end

  def prepare_category_breakdown_data(user)
    start_date = Time.current.beginning_of_month
    end_date = Time.current.end_of_month

    categories = Transaction.total_by_category(
      user,
      start_date,
      end_date
    )

    # Format for Chartkick pie/donut chart
    categories.map { |cat| [ cat.name, cat.total_cents / 100.0 ] }.to_h
  end

  def prepare_spending_trend_data(user)
    # Last 6 months
    end_date = Date.current.end_of_month
    start_date = 6.months.ago.beginning_of_month

    monthly_data = Transaction.time_series_by_month(
      user,
      start_date,
      end_date,
      type: :expenses
    )

    monthly_data.transform_values { |cents| cents / 100.0 }
  end

  def prepare_merchant_analytics_data(user)
    start_date = Time.current.beginning_of_month
    end_date = Time.current.end_of_month

    merchants = Transaction.total_by_merchant(
      user,
      start_date,
      end_date
    ).first(10) # Top 10 merchants

    merchants.map { |m| [ m.description, m.total_cents / 100.0 ] }.to_h
  end

  def prepare_daily_average_data(user)
    # Last 30 days average
    start_date = 30.days.ago.beginning_of_day
    end_date = Time.current.end_of_day

    daily_data = Transaction.time_series_by_day(
      user,
      start_date,
      end_date,
      type: :expenses
    )

    # Calculate average
    total = daily_data.values.sum
    days_count = daily_data.keys.length
    average = days_count > 0 ? (total / days_count / 100.0) : 0

    # Format as single value chart or line chart showing daily vs average
    {
      daily: daily_data.transform_values { |cents| cents / 100.0 },
      average: average
    }
  end
end
