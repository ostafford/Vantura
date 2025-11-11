module DashboardHelper
  # Delegate accessor methods for @dashboard_data
  # This keeps views clean and follows Rails conventions

  # Expense statistics
  def expense_total
    @dashboard_data&.dig(:expense_total)
  end

  def expense_count
    @dashboard_data&.dig(:expense_count)
  end

  # Income statistics
  def income_total
    @dashboard_data&.dig(:income_total)
  end

  def income_count
    @dashboard_data&.dig(:income_count)
  end

  # Projected income statistics
  def projected_income_total
    @dashboard_data&.dig(:projected_income_total) || 0
  end

  def projected_income_count
    @dashboard_data&.dig(:projected_income_count) || 0
  end

  # Projected expense statistics
  def projected_expense_total
    @dashboard_data&.dig(:projected_expense_total) || 0
  end

  def projected_expense_count
    @dashboard_data&.dig(:projected_expense_count) || 0
  end

  # Date and timing
  def current_date
    @dashboard_data&.dig(:current_date)
  end

  # Balance projections
  def end_of_month_balance
    @dashboard_data&.dig(:end_of_month_balance)
  end

  # Top merchants
  def top_expense_merchants
    @dashboard_data&.dig(:top_expense_merchants) || []
  end

  def top_income_merchants
    @dashboard_data&.dig(:top_income_merchants) || []
  end

  # Recent transactions
  def recent_transactions
    @dashboard_data&.dig(:recent_transactions) || []
  end

  # Upcoming recurring transactions
  def upcoming_recurring_expenses
    @dashboard_data&.dig(:upcoming_recurring_expenses) || []
  end

  def upcoming_recurring_income
    @dashboard_data&.dig(:upcoming_recurring_income) || []
  end

  def upcoming_recurring_total
    @dashboard_data&.dig(:upcoming_recurring_total)
  end

  # Balance card data
  def balance_at_month_start
    @dashboard_data&.dig(:balance_at_month_start)
  end

  def balance_change_since_month_start
    @dashboard_data&.dig(:balance_change_since_month_start) || 0
  end

  def average_daily_spending
    @dashboard_data&.dig(:average_daily_spending) || 0
  end

  def on_track_status
    @dashboard_data&.dig(:on_track_status) || :on_track
  end

  def income_frequency_data
    @dashboard_data&.dig(:income_frequency_data) || {}
  end

  def on_track_badge_props(status)
    normalized_status = status.respond_to?(:to_sym) ? status.to_sym : :on_track

    container_classes = {
      on_track: "bg-green-500/30 text-green-200 border-green-400/50",
      caution: "bg-yellow-500/30 text-yellow-200 border-yellow-400/50",
      off_track: "bg-red-500/30 text-red-200 border-red-400/50"
    }

    indicator_classes = {
      on_track: "bg-green-300",
      caution: "bg-yellow-300",
      off_track: "bg-red-300"
    }

    labels = {
      on_track: "On Track",
      caution: "Caution",
      off_track: "Off Track"
    }

    {
      label: labels.fetch(normalized_status, labels[:on_track]),
      container_classes: container_classes.fetch(normalized_status, container_classes[:on_track]),
      indicator_classes: indicator_classes.fetch(normalized_status, indicator_classes[:on_track])
    }
  end

  # Cash flow card data
  def top_expense_categories
    @dashboard_data&.dig(:top_expense_categories) || []
  end

  def top_income_categories
    @dashboard_data&.dig(:top_income_categories) || []
  end

  # Calculate net cash flow card styling and display values
  # @param income_total [Numeric] Total income for the period
  # @param expense_total [Numeric] Total expenses for the period
  # @param expense_count [Integer] Number of expense transactions
  # @param income_count [Integer] Number of income transactions
  # @param current_date [Date] Current date for context
  # @return [Hash] Hash containing all calculated values for the net cash flow card
  def net_cash_flow_data(income_total:, expense_total:, expense_count:, income_count:, current_date:)
    # Calculate net cash flow (income - expenses)
    net_cash_flow = income_total - expense_total
    savings_rate = income_total > 0 ? ((income_total - expense_total) / income_total * 100) : 0

    # Determine if positive or negative
    is_positive = net_cash_flow >= 0
    color = is_positive ? "blue" : "expense"
    icon = is_positive ? "arrow-up" : "arrow-down"

    # Format the net cash flow
    formatted_net = "$#{number_with_precision(net_cash_flow, precision: 2)}"

    # Calculate additional insights
    total_transactions = expense_count + income_count
    avg_transaction = total_transactions > 0 ? ((income_total - expense_total) / total_transactions) : 0

    # Detail text for display
    detail_text = is_positive ? "Savings Rate: #{number_with_precision(savings_rate, precision: 1)}%" : "Deficit: $#{number_with_precision(expense_total - income_total, precision: 2)}"

    {
      net_cash_flow: net_cash_flow,
      savings_rate: savings_rate,
      is_positive: is_positive,
      color: color,
      icon: icon,
      formatted_net: formatted_net,
      total_transactions: total_transactions,
      avg_transaction: avg_transaction,
      detail_text: detail_text
    }
  end
end
