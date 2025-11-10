# Service Object: Generate actionable budget plans based on historical data
#
# Usage:
#   coach = BudgetCoachService.new(account)
#   budget_plan = coach.generate_budget_plan
#
# Purpose: Calculate realistic category-level budgets that help users stay on track
#          Only generates when overspending is projected or user is close to limit
#
class BudgetCoachService
  # Essential categories (fixed expenses - don't suggest reductions)
  ESSENTIAL_CATEGORIES = %w[
    rent mortgage housing utilities insurance healthcare medical
    loan repayment debt car payment vehicle transport
  ].freeze

  # Variable categories (discretionary - can suggest reductions)
  VARIABLE_CATEGORIES = %w[
    groceries food dining restaurants shopping entertainment
    recreation hobbies personal care clothing gifts
    travel vacation subscriptions streaming
  ].freeze

  def initialize(account, reference_date = Date.today)
    @account = account
    @reference_date = reference_date
    @current_month_start = @reference_date.beginning_of_month
    @current_month_end = @reference_date.end_of_month
    @velocity_calculator = SpendingVelocityCalculator.new(@account, @reference_date)
  end

  # Generate budget plan if user is overspending or close to limit
  def generate_budget_plan
    current_month_income = calculate_current_month_income
    projected_spending = @velocity_calculator.projected_month_end_spending[:projected_total]
    projected_savings = current_month_income - projected_spending

    # Only generate if overspending is projected or very close to limit (within $100)
    return nil if projected_savings > 100

    # Calculate savings goal from historical data
    savings_goal = calculate_adaptive_savings_goal

    # Calculate target spending (income - savings goal)
    target_spending = current_month_income - savings_goal

    # Analyze category spending
    category_analysis = analyze_category_spending(3) # 3-month weighted average

    # Generate category budgets
    category_budgets = generate_category_budgets(
      category_analysis,
      target_spending,
      projected_spending
    )

    # Only return if we have actionable category budgets
    return nil if category_budgets.empty?

    {
      current_month_income: current_month_income,
      projected_spending: projected_spending,
      projected_savings: projected_savings,
      savings_goal: savings_goal,
      target_spending: target_spending,
      category_budgets: category_budgets,
      days_remaining: @velocity_calculator.current_velocity[:days_remaining],
      current_spent: @velocity_calculator.current_velocity[:total_spent]
    }
  end

  private

  # Calculate adaptive savings goal from historical data (6 months, weighted)
  def calculate_adaptive_savings_goal
    historical_data = analyze_historical_savings(6)
    avg_savings = historical_data[:average_monthly_savings]

    # If user has positive savings history, use 80% of average (achievable)
    if avg_savings > 0
      base_goal = avg_savings * 0.8
    else
      # User typically overspends - goal is to break even or small positive
      base_goal = 0
    end

    # Adjust based on current month income vs historical average
    current_income = calculate_current_month_income
    historical_avg_income = historical_data[:average_monthly_income]

    if historical_avg_income.positive?
      income_ratio = current_income / historical_avg_income

      # If income is significantly higher, can save more
      if income_ratio > 1.2
        base_goal = base_goal * 1.2
      # If income is lower, adjust goal down
      elsif income_ratio < 0.8
        base_goal = base_goal * 0.6
      end
    end

    # Ensure goal is non-negative and realistic
    [base_goal.round(2), 0].max
  end

  # Analyze historical savings with weighted months (recent = more weight)
  def analyze_historical_savings(months)
    monthly_breakdown = []
    total_savings = 0.0
    total_income = 0.0
    weights = []

    months.times do |i|
      month_date = @reference_date - i.months
      month_start = month_date.beginning_of_month
      month_end = month_date.end_of_month

      income = @account.transactions
                      .real
                      .income
                      .where(transaction_date: month_start..month_end)
                      .sum(:amount)
                      .abs

      expenses = @account.transactions
                        .real
                        .expenses
                        .where(transaction_date: month_start..month_end)
                        .sum(:amount)
                        .abs

      savings = income - expenses
      weight = 1.0 - (i * 0.1) # Recent months weighted more (1.0, 0.9, 0.8, etc.)

      monthly_breakdown << {
        month: month_date.strftime("%B %Y"),
        income: income,
        expenses: expenses,
        savings: savings,
        weight: weight
      }

      total_savings += savings * weight
      total_income += income * weight
      weights << weight
    end

    total_weight = weights.sum
    avg_savings = total_weight.positive? ? (total_savings / total_weight) : 0.0
    avg_income = total_weight.positive? ? (total_income / total_weight) : 0.0

    {
      months_analyzed: months,
      average_monthly_savings: avg_savings.round(2),
      average_monthly_income: avg_income.round(2),
      monthly_breakdown: monthly_breakdown.reverse
    }
  end

  # Analyze category spending with weighted 3-month average
  def analyze_category_spending(months)
    category_data = {}
    weights = []

    months.times do |i|
      month_date = @reference_date - i.months
      month_start = month_date.beginning_of_month
      month_end = month_date.end_of_month
      weight = 1.0 - (i * 0.15) # More weight on recent (1.0, 0.85, 0.7)

      transactions = @account.transactions
                            .real
                            .expenses
                            .where(transaction_date: month_start..month_end)
                            .where.not(category: [ nil, "" ])

      transactions.group_by(&:category).each do |category, category_transactions|
        category_name = category || "Uncategorized"
        month_total = category_transactions.sum { |t| t.amount.abs }
        month_count = category_transactions.count

        category_data[category_name] ||= {
          name: category_name,
          weighted_total: 0.0,
          weighted_count: 0.0,
          total_weight: 0.0,
          months_seen: 0,
          is_essential: essential_category?(category_name),
          is_variable: variable_category?(category_name)
        }

        category_data[category_name][:weighted_total] += month_total * weight
        category_data[category_name][:weighted_count] += month_count * weight
        category_data[category_name][:total_weight] += weight
        category_data[category_name][:months_seen] += 1
      end

      weights << weight
    end

    total_weight = weights.sum

    # Calculate weighted averages
    category_data.values.map do |data|
      avg_amount = data[:total_weight].positive? ? (data[:weighted_total] / data[:total_weight]) : 0.0
      avg_count = data[:total_weight].positive? ? (data[:weighted_count] / data[:total_weight]) : 0.0

      {
        name: data[:name],
        average_monthly_amount: avg_amount.round(2),
        average_monthly_count: avg_count.round(1),
        months_seen: data[:months_seen],
        is_essential: data[:is_essential],
        is_variable: data[:is_variable]
      }
    end.select { |c| c[:average_monthly_amount] > 0 }
       .sort_by { |c| -c[:average_monthly_amount] } # Highest spending first
  end

  # Generate category budgets based on target spending
  def generate_category_budgets(category_analysis, target_spending, projected_spending)
    # Separate essential and variable categories
    essential_categories = category_analysis.select { |c| c[:is_essential] }
    variable_categories = category_analysis.select { |c| c[:is_variable] }

    # Calculate current month spending by category
    current_month_categories = calculate_current_month_categories

    # Calculate essential spending (fixed - don't reduce)
    essential_total = essential_categories.sum do |cat|
      current_month_categories[cat[:name]] || cat[:average_monthly_amount]
    end

    # Calculate variable spending available
    variable_budget = target_spending - essential_total

    # If variable budget is negative, can't create realistic plan
    return [] if variable_budget < 0

    # Calculate current variable spending
    current_variable_spending = variable_categories.sum do |cat|
      current_month_categories[cat[:name]] || cat[:average_monthly_amount]
    end

    # Calculate reduction needed
    reduction_needed = current_variable_spending - variable_budget

    # If no reduction needed, return empty (user is on track)
    return [] if reduction_needed <= 0

    # Generate budgets for top variable categories (prioritize highest spending, most frequent, upward trends)
    budgets = []
    total_reduction_allocated = 0.0

    # Sort variable categories by priority (spending amount, frequency, trend)
    prioritized = variable_categories.sort_by do |cat|
      current_amount = current_month_categories[cat[:name]] || cat[:average_monthly_amount]
      priority_score = (
        (current_amount / current_variable_spending) * 0.4 + # 40% weight: highest spending
        (cat[:average_monthly_count] / 30.0) * 0.3 + # 30% weight: most frequent
        0.3 # 30% weight: upward trend (simplified for now)
      )
      -priority_score # Negative for descending sort
    end

    # Allocate reductions to top 3-5 categories
    top_categories = prioritized.first(5)

    top_categories.each_with_index do |cat, index|
      current_amount = current_month_categories[cat[:name]] || cat[:average_monthly_amount]
      proportion = current_amount / current_variable_spending

      # Allocate reduction proportionally, but ensure minimum viable amount
      suggested_reduction = reduction_needed * proportion
      suggested_budget = [current_amount - suggested_reduction, current_amount * 0.7].max # Don't reduce more than 30%

      # Calculate weekly target
      weeks_remaining = (@velocity_calculator.current_velocity[:days_remaining] / 7.0).ceil
      weeks_remaining = [weeks_remaining, 1].max
      weekly_target = (suggested_budget / weeks_remaining).round(2)

      # Only include if reduction is meaningful (> $10)
      if suggested_reduction > 10
        budgets << {
          category: cat[:name],
          current_spent: current_amount.round(2),
          suggested_budget: suggested_budget.round(2),
          weekly_target: weekly_target,
          reduction_amount: suggested_reduction.round(2),
          reduction_percentage: ((suggested_reduction / current_amount) * 100).round(1)
        }

        total_reduction_allocated += suggested_reduction
      end
    end

    budgets
  end

  # Calculate current month spending by category
  def calculate_current_month_categories
    @current_month_categories ||= begin
      transactions = @account.transactions
                              .real
                              .expenses
                              .where(transaction_date: @current_month_start..@reference_date)
                              .where.not(category: [ nil, "" ])

      transactions.group_by(&:category).transform_values do |category_transactions|
        category_transactions.sum { |t| t.amount.abs }
      end
    end
  end

  # Calculate current month income (including expected if not yet received)
  def calculate_current_month_income
    month_start = @current_month_start
    month_end = @current_month_end

    # Actual income received so far
    actual_income = @account.transactions
                            .real
                            .income
                            .where(transaction_date: month_start..@reference_date)
                            .sum(:amount)
                            .abs

    # If we're early in month and income is low, check historical patterns
    days_elapsed = (@reference_date - month_start).to_i + 1
    if actual_income < 100 && days_elapsed < 15
      # Check historical average for this month
      historical = analyze_historical_savings(6)
      avg_income = historical[:average_monthly_income]

      # If historical average is much higher, use it as expected income
      if avg_income > actual_income * 2
        return avg_income.round(2)
      end
    end

    actual_income.round(2)
  end

  # Check if category is essential (fixed expense)
  def essential_category?(category_name)
    normalized = category_name.downcase.strip
    ESSENTIAL_CATEGORIES.any? { |essential| normalized.include?(essential) }
  end

  # Check if category is variable (discretionary expense)
  def variable_category?(category_name)
    normalized = category_name.downcase.strip
    VARIABLE_CATEGORIES.any? { |variable| normalized.include?(variable) }
  end
end

