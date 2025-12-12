class CalendarProjectionService
  def self.calculate(user:, start_date:, end_date:)
    current_balance = user.accounts.transactional.sum(:balance_cents)

    # Get planned transactions
    base_planned = user.planned_transactions
                       .by_date_range(start_date, end_date)
                       .includes(:category, :transaction_record)

    all_planned = base_planned.flat_map do |pt|
      pt.occurrences_for_month(start_date.year, start_date.month)
    end

    # Get actual transactions (use settled_at for more accurate date grouping)
    actual_transactions = user.transactions
                              .by_settled_date_range(start_date.beginning_of_day, end_date.end_of_day)
                              .includes(:account, :category)

    projection_data = sequential_projection(
      start_date: start_date,
      end_date: end_date,
      current_balance: current_balance,
      planned_transactions: all_planned,
      actual_transactions: actual_transactions
    )

    weekly_projection = calculate_weekly_projection(projection_data, start_date)
    monthly_projection = projection_data[end_date]&.dig(:balance_cents) || current_balance

    {
      projection_data: projection_data,
      weekly_projection: weekly_projection,
      monthly_projection: monthly_projection,
      current_balance: current_balance
    }
  end

  private

  # Sequential day-by-day projection calculation
  def self.sequential_projection(start_date:, end_date:, current_balance:, planned_transactions:, actual_transactions:)
    projection = {}
    running_balance = current_balance

    # Group transactions by date
    planned_by_date = planned_transactions.group_by { |pt| pt[:date] }
    # Prefer settled_at (when transaction actually occurred), fall back to created_at_up, then created_at
    actual_by_date = actual_transactions.group_by do |t|
      t.settled_at&.to_date || t.created_at_up&.to_date || t.created_at.to_date
    end

    # Process each day sequentially
    (start_date..end_date).each do |date|
      day_planned = planned_by_date[date] || []
      day_actual = actual_by_date[date] || []

      # Calculate totals for the day
      # Planned transactions: amount_cents is positive for both income and expense, transaction_type determines sign
      planned_income = day_planned.select { |pt| pt[:transaction_type] == "income" }.sum { |pt| pt[:amount_cents] }
      planned_expenses_amount = day_planned.select { |pt| pt[:transaction_type] == "expense" }.sum { |pt| pt[:amount_cents] }
      # Actual transactions: amount_cents is negative for expenses, positive for income
      actual_income = day_actual.select { |t| t.amount_cents > 0 }.sum(&:amount_cents)
      actual_expenses = day_actual.select { |t| t.amount_cents < 0 }.sum(&:amount_cents)

      # Apply transactions to running balance
      # Income adds to balance, expenses subtract from balance
      running_balance += actual_income
      running_balance += actual_expenses # expenses are already negative
      running_balance += planned_income
      running_balance -= planned_expenses_amount # planned expenses are positive, so subtract

      projection[date] = {
        balance_cents: running_balance,
        planned_count: day_planned.count,
        planned_total: planned_income - planned_expenses_amount, # Net planned (income - expenses)
        planned_income: planned_income,
        planned_expenses: -planned_expenses_amount, # Store as negative for consistency
        actual_count: day_actual.count,
        actual_total: actual_income + actual_expenses, # actual_expenses is already negative
        actual_income: actual_income,
        actual_expenses: actual_expenses,
        planned_transactions: day_planned,
        actual_transactions: day_actual
      }
    end

    projection
  end

  def self.calculate_weekly_projection(projection_data, start_of_month)
    weeks = []
    current_week_start = start_of_month.beginning_of_week

    while current_week_start <= start_of_month.end_of_month
      week_end = [ current_week_start.end_of_week, start_of_month.end_of_month ].min

      week_balance = projection_data[week_end]&.dig(:balance_cents) || projection_data.values.last&.dig(:balance_cents) || 0

      weeks << {
        start_date: current_week_start,
        end_date: week_end,
        balance_cents: week_balance
      }

      current_week_start = week_end + 1.day
    end

    weeks
  end
end
