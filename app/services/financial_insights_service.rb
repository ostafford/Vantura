# Service Object: Generate actionable, evidence-based financial insights
#
# Usage:
#   insights = FinancialInsightsService.new(account)
#   velocity_insight = insights.spending_velocity_insight
#   savings_insight = insights.savings_opportunity_insight
#
# Purpose: Generate actionable recommendations with evidence-based explanations
#
class FinancialInsightsService
  def initialize(account, reference_date = Date.today)
    @account = account
    @reference_date = reference_date
    @velocity_calculator = SpendingVelocityCalculator.new(@account, @reference_date)
  end

  # Analyze spending velocity and generate insight
  def spending_velocity_insight
    current = @velocity_calculator.current_velocity
    historical = @velocity_calculator.historical_average(6)
    change_pct = @velocity_calculator.velocity_change_pct(6)
    projected = @velocity_calculator.projected_month_end_spending

    # Contextual threshold: 5% for warnings (spending faster), 5% for positive (spending slower)
    threshold = 5
    return nil if change_pct.abs < threshold

    if change_pct < 0
      # Spending slower - positive insight
      savings_opp = @velocity_calculator.savings_opportunity(6)
      if savings_opp[:opportunity_exists]
        {
          type: "spending_velocity",
          title: "Spending Slower Than Usual",
          message: generate_velocity_message(current, historical, change_pct, projected, savings_opp),
          evidence: {
            current_daily_rate: current[:daily_rate],
            historical_daily_rate: historical[:average_daily_rate],
            change_percentage: change_pct,
            current_spent: current[:total_spent],
            days_elapsed: current[:days_elapsed],
            projected_month_end: projected[:projected_total],
            historical_monthly_avg: savings_opp[:historical_average],
            potential_savings: savings_opp[:potential_savings],
            analysis_period: "6 months"
          },
          suggested_action: "Create Savings Transfer",
          suggested_amount: savings_opp[:potential_savings],
          suggested_date: @reference_date.end_of_month,
          priority: "high"
        }
      else
        nil
      end
    else
      # Spending faster - warning insight
      {
        type: "spending_velocity",
        title: "Spending Faster Than Usual",
        message: generate_velocity_warning_message(current, historical, change_pct, projected),
        evidence: {
          current_daily_rate: current[:daily_rate],
          historical_daily_rate: historical[:average_daily_rate],
          change_percentage: change_pct,
          current_spent: current[:total_spent],
          days_elapsed: current[:days_elapsed],
          projected_month_end: projected[:projected_total],
          historical_monthly_avg: (historical[:average_daily_rate] * 30.44).round(2),
          analysis_period: "6 months"
        },
        suggested_action: "Review Spending",
        suggested_amount: nil,
        suggested_date: nil,
        priority: "high"
      }
    end
  end

  # Spending warning when expenses exceed income
  def spending_warning_insight
    current_month_income = calculate_current_month_income
    projected_spending = @velocity_calculator.projected_month_end_spending[:projected_total]
    projected_savings = current_month_income - projected_spending

    # Only show if expenses exceed income
    return nil if projected_savings >= 0

    overspend_amount = projected_savings.abs
    current_spent = @velocity_calculator.current_velocity[:total_spent]
    days_elapsed = @velocity_calculator.current_velocity[:days_elapsed]
    days_remaining = @velocity_calculator.current_velocity[:days_remaining]

    {
      type: "spending_warning",
      title: "Expenses Exceed Income",
      message: generate_spending_warning_message(current_month_income, projected_spending, overspend_amount, days_remaining),
      evidence: {
        current_month_income: current_month_income,
        projected_spending: projected_spending,
        projected_savings: projected_savings,
        overspend_amount: overspend_amount,
        current_spent: current_spent,
        days_elapsed: days_elapsed,
        days_remaining: days_remaining,
        analysis_period: "Current month projection"
      },
      suggested_action: "Review Spending",
      suggested_amount: nil,
      suggested_date: nil,
      priority: "high"
    }
  end

  # Negative savings pattern warning
  def negative_savings_pattern_insight
    savings_data = analyze_recent_savings(3)
    monthly_breakdown = savings_data[:monthly_breakdown]

    # Count months with negative savings
    negative_months = monthly_breakdown.count { |m| m[:savings] < 0 }

    # Only show if 2+ months have negative savings
    return nil if negative_months < 2

    avg_monthly_savings = savings_data[:average_monthly_savings]
    total_negative = monthly_breakdown.sum { |m| m[:savings] < 0 ? m[:savings].abs : 0 }

    {
      type: "negative_savings_pattern",
      title: "Consistent Overspending Pattern",
      message: generate_negative_savings_message(monthly_breakdown, negative_months, avg_monthly_savings, total_negative),
      evidence: {
        months_analyzed: savings_data[:months_analyzed],
        negative_months_count: negative_months,
        average_monthly_savings: avg_monthly_savings,
        total_overspend: total_negative,
        monthly_breakdown: monthly_breakdown,
        analysis_period: "3 months"
      },
      suggested_action: "Review Spending Habits",
      suggested_amount: nil,
      suggested_date: nil,
      priority: "high"
    }
  end

  # Combined Savings & Investment Opportunity Insight
  # This merges savings opportunity and investment suggestion into one dynamic insight
  def savings_investment_opportunity
    # Check for immediate savings opportunity (6-month comparison)
    savings_opp = @velocity_calculator.savings_opportunity(6)
    current_month_income = calculate_current_month_income
    projected_spending = @velocity_calculator.projected_month_end_spending[:projected_total]
    projected_savings = current_month_income - projected_spending

    # Check for consistent savings pattern (3-month analysis)
    savings_data = analyze_recent_savings(3)
    has_consistent_savings = savings_data[:consistent_savings]
    avg_monthly_savings = savings_data[:average_monthly_savings]
    suggested_investment = has_consistent_savings && avg_monthly_savings > 100 ? (avg_monthly_savings * 0.5).round(2) : nil

    # Only generate insight if there's either a savings opportunity OR consistent savings pattern
    return nil unless savings_opp[:opportunity_exists] || has_consistent_savings

    # Determine priority and message based on what's available
    if savings_opp[:opportunity_exists] && has_consistent_savings
      # Both conditions met - strongest insight
      {
        type: "savings_investment_opportunity",
        title: "Savings & Investment Opportunity",
        message: generate_combined_savings_investment_message(
          savings_opp, current_month_income, projected_spending, projected_savings,
          savings_data, suggested_investment
        ),
        evidence: {
          # Savings opportunity data (6-month comparison)
          current_income: current_month_income,
          projected_spending: projected_spending,
          projected_savings: projected_savings,
          potential_additional_savings: savings_opp[:potential_savings],
          historical_average_spending: savings_opp[:historical_average],
          current_velocity: @velocity_calculator.current_velocity[:daily_rate],
          # Investment pattern data (3-month analysis)
          months_analyzed: savings_data[:months_analyzed],
          average_monthly_savings: avg_monthly_savings,
          monthly_savings_breakdown: savings_data[:monthly_breakdown],
          suggested_monthly_investment: suggested_investment,
          remaining_for_expenses: suggested_investment ? (avg_monthly_savings - suggested_investment).round(2) : nil,
          # Time periods for transparency
          savings_analysis_period: "6 months",
          investment_analysis_period: "3 months"
        },
        suggested_action: suggested_investment && suggested_investment >= 50 ? "Set Up Investment Plan" : "Create Savings Transfer",
        suggested_amount: suggested_investment && suggested_investment >= 50 ? suggested_investment : savings_opp[:potential_savings],
        suggested_date: suggested_investment && suggested_investment >= 50 ? (@reference_date + 1.month).beginning_of_month : @reference_date.end_of_month,
        priority: "high"
      }
    elsif savings_opp[:opportunity_exists]
      # Only savings opportunity exists
      {
        type: "savings_investment_opportunity",
        title: "Savings Opportunity Detected",
        message: generate_savings_only_message(savings_opp, current_month_income, projected_spending, projected_savings),
        evidence: {
          current_income: current_month_income,
          projected_spending: projected_spending,
          projected_savings: projected_savings,
          potential_additional_savings: savings_opp[:potential_savings],
          historical_average_spending: savings_opp[:historical_average],
          current_velocity: @velocity_calculator.current_velocity[:daily_rate],
          savings_analysis_period: "6 months"
        },
        suggested_action: "Create Savings Transfer",
        suggested_amount: savings_opp[:potential_savings],
        suggested_date: @reference_date.end_of_month,
        priority: "high"
      }
    else
      # Only consistent savings pattern exists
      return nil if suggested_investment.nil? || suggested_investment < 50

      {
        type: "savings_investment_opportunity",
        title: "Investment Opportunity Based on Savings Pattern",
        message: generate_investment_only_message(savings_data, suggested_investment),
        evidence: {
          months_analyzed: savings_data[:months_analyzed],
          average_monthly_savings: avg_monthly_savings,
          monthly_savings_breakdown: savings_data[:monthly_breakdown],
          suggested_monthly_investment: suggested_investment,
          remaining_for_expenses: (avg_monthly_savings - suggested_investment).round(2),
          investment_analysis_period: "3 months"
        },
        suggested_action: "Set Up Investment Plan",
        suggested_amount: suggested_investment,
        suggested_date: (@reference_date + 1.month).beginning_of_month,
        priority: "medium"
      }
    end
  end

  # Legacy methods kept for backwards compatibility (deprecated)
  def savings_opportunity_insight
    savings_investment_opportunity
  end

  def investment_suggestion
    savings_investment_opportunity
  end

  # Day-of-week spending pattern insight
  def day_of_week_pattern_insight
    # Analyze last 3 months of spending by day of week
    start_date = (@reference_date - 3.months).beginning_of_month
    end_date = @reference_date.end_of_month

    transactions = @account.transactions
                          .real
                          .expenses
                          .where(transaction_date: start_date..end_date)

    return nil if transactions.count < 20 # Need sufficient data

    # Group by day of week (0 = Sunday, 6 = Saturday)
    day_totals = transactions.group_by { |t| t.transaction_date.wday }
                             .transform_values do |day_transactions|
                               {
                                 total: day_transactions.sum { |t| t.amount.abs },
                                 count: day_transactions.count,
                                 average: day_transactions.sum { |t| t.amount.abs } / day_transactions.count.to_f
                               }
                             end

    return nil if day_totals.empty?

    # Find the day with highest average spending
    top_day_data = day_totals.max_by { |_, data| data[:average] }
    top_day = top_day_data[0]
    top_day_info = top_day_data[1]

    day_names = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday]
    day_name = day_names[top_day]

    # Calculate overall average to compare
    overall_avg = transactions.sum { |t| t.amount.abs } / transactions.count.to_f

    # Only show if the top day is significantly higher (at least 30% more)
    return nil if top_day_info[:average] < overall_avg * 1.3

    # Calculate monthly frequency (how many times per month on average)
    weeks_in_period = ((end_date - start_date).to_f / 7).ceil
    monthly_frequency = (top_day_info[:count].to_f / weeks_in_period * 4.33).round(1)

    {
      type: "day_of_week_pattern",
      title: "Higher Spending on #{day_name}s",
      message: generate_day_of_week_message(day_name, top_day_info, monthly_frequency, overall_avg),
      evidence: {
        top_day: day_name,
        top_day_average: top_day_info[:average],
        top_day_total: top_day_info[:total],
        top_day_count: top_day_info[:count],
        monthly_frequency: monthly_frequency,
        overall_average: overall_avg,
        day_breakdown: day_totals.transform_keys { |wday| day_names[wday] },
        analysis_period: "3 months"
      },
      suggested_action: "Review #{day_name} Transactions",
      suggested_amount: nil,
      suggested_date: nil,
      priority: "low"
    }
  end

  # Merchant habit pattern insight (e.g., takeout frequency)
  def merchant_habit_pattern_insight
    # Analyze last 3 months for merchant patterns
    start_date = (@reference_date - 3.months).beginning_of_month
    end_date = @reference_date.end_of_month

    transactions = @account.transactions
                          .real
                          .expenses
                          .where(transaction_date: start_date..end_date)
                          .where.not(merchant: [ nil, "" ])

    return nil if transactions.count < 10

    # Group by merchant and analyze frequency
    merchant_data = transactions.group_by(&:merchant)
                                 .transform_values do |merchant_transactions|
                                   {
                                     total: merchant_transactions.sum { |t| t.amount.abs },
                                     count: merchant_transactions.count,
                                     average: merchant_transactions.sum { |t| t.amount.abs } / merchant_transactions.count.to_f,
                                     dates: merchant_transactions.map(&:transaction_date).sort
                                   }
                                 end

    # Find merchants with high frequency (appears multiple times per month on average)
    months_in_period = ((end_date - start_date).to_f / 30.44).round(1)

    significant_merchants = merchant_data.select do |merchant, data|
      monthly_frequency = (data[:count].to_f / months_in_period).round(1)
      monthly_frequency >= 2 && data[:average] >= 20 # At least 2x/month and $20+ average
    end

    return nil if significant_merchants.empty?

    # Pick the merchant with highest monthly spend (frequency * average)
    top_merchant = significant_merchants.max_by do |merchant, data|
      monthly_frequency = (data[:count].to_f / months_in_period).round(1)
      monthly_frequency * data[:average]
    end

    merchant_name = top_merchant[0]
    merchant_info = top_merchant[1]
    monthly_frequency = (merchant_info[:count].to_f / months_in_period).round(1)
    monthly_total = monthly_frequency * merchant_info[:average]

    {
      type: "merchant_habit_pattern",
      title: "Frequent Spending at #{merchant_name}",
      message: generate_merchant_habit_message(merchant_name, merchant_info, monthly_frequency, monthly_total, months_in_period),
      evidence: {
        merchant_name: merchant_name,
        total_spent: merchant_info[:total],
        transaction_count: merchant_info[:count],
        average_per_transaction: merchant_info[:average],
        monthly_frequency: monthly_frequency,
        estimated_monthly_total: monthly_total,
        analysis_period: "#{months_in_period.round(0)} months"
      },
      suggested_action: "Review Transactions",
      suggested_amount: nil,
      suggested_date: nil,
      priority: "low"
    }
  end

  # Category or merchant insight based on view type
  def category_merchant_insight(view_type = "category")
    breakdown = if view_type == "merchant"
                  get_top_merchants
    else
                  get_top_categories
    end

    return nil if breakdown.empty?

    top_item = breakdown.first
    trend = calculate_trend_for_item(top_item, view_type)

    {
      type: "category_merchant",
      title: "Top #{view_type.capitalize}: #{top_item[:name]}",
      message: generate_category_merchant_message(top_item, trend, view_type),
      evidence: {
        item_name: top_item[:name],
        total_amount: top_item[:amount],
        transaction_count: top_item[:count],
        view_type: view_type,
        trend: trend
      },
      suggested_action: "Review Transactions",
      suggested_amount: nil,
      suggested_date: nil,
      priority: "low"
    }
  end

  # Budget Coach Insight - Actionable budget plan when overspending is projected
  def budget_coach_insight
    coach = BudgetCoachService.new(@account, @reference_date)
    budget_plan = coach.generate_budget_plan

    return nil if budget_plan.nil?

    # Determine priority based on overspending severity
    overspend_amount = budget_plan[:projected_savings].abs
    priority = if overspend_amount > 500
      "high"
    elsif overspend_amount > 100
      "medium"
    else
      "medium" # Still show when close to limit
    end

    {
      type: "budget_coach",
      title: generate_budget_coach_title(budget_plan),
      message: generate_budget_coach_message(budget_plan),
      evidence: {
        current_month_income: budget_plan[:current_month_income],
        projected_spending: budget_plan[:projected_spending],
        projected_savings: budget_plan[:projected_savings],
        savings_goal: budget_plan[:savings_goal],
        target_spending: budget_plan[:target_spending],
        days_remaining: budget_plan[:days_remaining],
        current_spent: budget_plan[:current_spent],
        category_budgets: budget_plan[:category_budgets],
        analysis_period: "3 months (weighted)"
      },
      suggested_action: "Follow Category Budgets",
      suggested_amount: nil,
      suggested_date: nil,
      priority: priority
    }
  end

  # Generate all insights (top 2-3 for dashboard) with contextual filtering
  def generate_key_insights(limit = 3)
    insights = []
    context = determine_context

    # Priority order: warnings first, then opportunities
    # High priority warnings (always shown regardless of context)
    insights << spending_warning_insight
    insights << negative_savings_pattern_insight
    insights << spending_velocity_insight

    # Budget Coach (only when overspending is projected)
    insights << budget_coach_insight

    # Opportunities (context-aware)
    insights << savings_investment_opportunity if should_show_savings_insight?(context)

    # Pattern-based insights (context-aware, lower priority)
    insights << day_of_week_pattern_insight if should_show_pattern_insights?(context)
    insights << merchant_habit_pattern_insight if should_show_pattern_insights?(context)

    # Filter out nil, sort by priority, limit
    insights.compact
            .sort_by { |i| priority_weight(i[:priority]) }
            .reverse
            .first(limit)
  end

  # Debug method to understand why insights aren't generating
  # Usage in Rails console: FinancialInsightsService.new(account).debug_insights
  def debug_insights
    puts "\n=== INSIGHT DEBUG INFORMATION ===\n\n"

    # Check spending velocity
    current = @velocity_calculator.current_velocity
    historical = @velocity_calculator.historical_average(6)
    change_pct = @velocity_calculator.velocity_change_pct(6)
    projected = @velocity_calculator.projected_month_end_spending

    puts "SPENDING VELOCITY CHECK:"
    puts "  Current daily rate: $#{current[:daily_rate]}"
    puts "  6-month average: $#{historical[:average_daily_rate]}"
    puts "  Change percentage: #{change_pct}%"
    puts "  Required: >10% change"
    puts "  Status: #{change_pct.abs >= 10 ? '✅ QUALIFIES' : '❌ Does not qualify (need >10% change)'}"
    puts ""

    # Check savings opportunity
    savings_opp = @velocity_calculator.savings_opportunity(6)
    current_month_income = calculate_current_month_income
    projected_spending = projected[:projected_total]
    projected_savings = current_month_income - projected_spending

    puts "SAVINGS OPPORTUNITY CHECK:"
    puts "  Current month income: $#{current_month_income.round(0)}"
    puts "  Projected spending: $#{projected_spending.round(0)}"
    puts "  Projected savings: $#{projected_savings.round(0)}"
    puts "  Historical average spending: $#{savings_opp[:historical_average].round(0)}"
    puts "  Opportunity exists: #{savings_opp[:opportunity_exists]}"
    puts "  Status: #{savings_opp[:opportunity_exists] ? '✅ QUALIFIES' : '❌ Does not qualify (projected spending must be < historical average)'}"
    puts ""

    # Check investment suggestion
    savings_data = analyze_recent_savings(3)
    has_consistent_savings = savings_data[:consistent_savings]
    avg_monthly_savings = savings_data[:average_monthly_savings]
    suggested_investment = has_consistent_savings && avg_monthly_savings > 100 ? (avg_monthly_savings * 0.5).round(2) : nil

    puts "INVESTMENT SUGGESTION CHECK (3-month analysis):"
    puts "  Months analyzed: #{savings_data[:months_analyzed]}"
    puts "  Monthly breakdown:"
    savings_data[:monthly_breakdown].each do |month|
      puts "    #{month[:month]}: Income $#{month[:income].round(0)}, Expenses $#{month[:expenses].round(0)}, Savings $#{month[:savings].round(0)}"
    end
    puts "  Average monthly savings: $#{avg_monthly_savings.round(0)}"
    puts "  Consistent savings: #{has_consistent_savings} (all 3 months must have savings > 0 AND average > $100)"
    puts "  Suggested investment: #{suggested_investment ? "$#{suggested_investment.round(0)}" : 'N/A'}"
    puts "  Required: Consistent savings AND suggested investment >= $50"
    puts "  Status: #{has_consistent_savings && suggested_investment && suggested_investment >= 50 ? '✅ QUALIFIES' : '❌ Does not qualify'}"
    puts ""

    # Combined check
    combined_qualifies = savings_opp[:opportunity_exists] || has_consistent_savings
    puts "COMBINED SAVINGS & INVESTMENT INSIGHT:"
    puts "  Status: #{combined_qualifies ? '✅ WOULD GENERATE' : '❌ Would not generate (need savings opportunity OR consistent savings pattern)'}"
    puts ""

    # Generate actual insights
    puts "GENERATED INSIGHTS:"
    insights = generate_key_insights(3)
    if insights.any?
      insights.each_with_index do |insight, i|
        puts "  #{i + 1}. #{insight[:title]} (#{insight[:type]}, priority: #{insight[:priority]})"
      end
    else
      puts "  ❌ No insights generated"
    end

    puts "\n=== END DEBUG ===\n"

    {
      spending_velocity: {
        qualifies: change_pct.abs >= 10,
        current_daily_rate: current[:daily_rate],
        historical_average: historical[:average_daily_rate],
        change_percentage: change_pct
      },
      savings_opportunity: {
        qualifies: savings_opp[:opportunity_exists],
        current_income: current_month_income,
        projected_spending: projected_spending,
        projected_savings: projected_savings,
        historical_average: savings_opp[:historical_average]
      },
      investment_suggestion: {
        qualifies: has_consistent_savings && suggested_investment && suggested_investment >= 50,
        consistent_savings: has_consistent_savings,
        average_monthly_savings: avg_monthly_savings,
        suggested_investment: suggested_investment,
        monthly_breakdown: savings_data[:monthly_breakdown]
      },
      combined_qualifies: combined_qualifies,
      generated_insights: insights
    }
  end

  private

  def generate_velocity_message(current, historical, change_pct, projected, savings_opp)
    "You're spending $#{current[:daily_rate]} per day, which is #{change_pct.abs}% " \
    "#{change_pct < 0 ? 'slower' : 'faster'} than your 6-month average of $#{historical[:average_daily_rate]} per day (based on last 6 months of data). " \
    "If you maintain this pace, you'll spend $#{projected[:projected_total].round(0)} this month, " \
    "compared to your average of $#{savings_opp[:historical_average].round(0)}. " \
    "This could result in $#{savings_opp[:potential_savings].round(0)} in additional savings. " \
    "Consider moving this amount to savings on #{@reference_date.end_of_month.strftime('%B %d')}."
  end

  def generate_velocity_warning_message(current, historical, change_pct, projected)
    "You're spending $#{current[:daily_rate]} per day, which is #{change_pct.abs}% faster than your " \
    "6-month average of $#{historical[:average_daily_rate]} per day (based on last 6 months of data). " \
    "At this pace, you're projected to spend $#{projected[:projected_total].round(0)} this month, " \
    "compared to your average of $#{(historical[:average_daily_rate] * 30.44).round(0)}. " \
    "Consider reviewing your recent transactions to identify areas where spending has increased."
  end

  def generate_spending_warning_message(income, projected_spending, overspend_amount, days_remaining)
    daily_reduction_needed = (overspend_amount / [ days_remaining, 1 ].max).round(2)
    weekly_reduction_needed = (daily_reduction_needed * 7).round(2)

    "Your projected spending of $#{projected_spending.round(0)} exceeds your income of $#{income.round(0)} by $#{overspend_amount.round(0)} this month. " \
    "With #{days_remaining} days remaining, you're on track to overspend. " \
    "To get back on track, try reducing daily spending by $#{daily_reduction_needed} (about $#{weekly_reduction_needed} per week) over the remaining days. " \
    "This would bring your month-end total to $#{income.round(0)}, matching your income. " \
    "Review your top spending categories to identify where you can make these reductions."
  end

  def generate_negative_savings_message(monthly_breakdown, negative_months, avg_monthly_savings, total_negative)
    monthly_reduction_target = (avg_monthly_savings.abs / 3.0).round(2) # Spread across 3 months
    weekly_reduction_target = (monthly_reduction_target / 4.33).round(2)

    "You've spent more than you earned in #{negative_months} out of the last 3 months, with an average overspend of $#{avg_monthly_savings.abs.round(0)} per month. " \
    "Total overspend: $#{total_negative.round(0)} across #{negative_months} months. " \
    "To break this pattern, aim to reduce monthly expenses by $#{monthly_reduction_target.round(0)} (about $#{weekly_reduction_target.round(0)} per week). " \
    "Start by reviewing your top 3 spending categories this month and identifying specific areas where you can cut back. " \
    "Small, consistent reductions are more sustainable than large one-time cuts."
  end

  def generate_combined_savings_investment_message(savings_opp, income, spending, savings, savings_data, suggested_investment)
    # Combined message when both savings opportunity and consistent savings pattern exist
    base_message = "Based on your current spending velocity (compared to your 6-month average), " \
                   "you're on track to save $#{savings.round(0)} this month, " \
                   "which is $#{savings_opp[:potential_savings].round(0)} more than your historical average. " \
                   "Your income is $#{income.round(0)} and projected spending is $#{spending.round(0)}. "

    if suggested_investment && suggested_investment >= 50
      base_message += "Additionally, you've consistently saved an average of $#{savings_data[:average_monthly_savings].round(0)} per month " \
                      "over the past #{savings_data[:months_analyzed]} months (3-month analysis). " \
                      "Once you hit your savings target, consider investing $#{suggested_investment.round(0)} per month starting " \
                      "#{(@reference_date + 1.month).beginning_of_month.strftime('%B %d')}. " \
                      "This would leave $#{(savings_data[:average_monthly_savings] - suggested_investment).round(0)} for expenses " \
                      "while building your investment portfolio."
    else
      base_message += "Consider setting up a hypothetical savings transfer of $#{savings_opp[:potential_savings].round(0)} " \
                      "on #{@reference_date.end_of_month.strftime('%B %d')} to visualize the impact."
    end

    base_message
  end

  def generate_savings_only_message(savings_opp, income, spending, savings)
    "Based on your current spending velocity (compared to your 6-month average), " \
    "you're on track to save $#{savings.round(0)} this month, " \
    "which is $#{savings_opp[:potential_savings].round(0)} more than your historical average. " \
    "Your income is $#{income.round(0)} and projected spending is $#{spending.round(0)}. " \
    "Consider setting up a hypothetical savings transfer of $#{savings_opp[:potential_savings].round(0)} " \
    "on #{@reference_date.end_of_month.strftime('%B %d')} to visualize the impact."
  end

  def generate_investment_only_message(savings_data, suggested_amount)
    "You've consistently saved an average of $#{savings_data[:average_monthly_savings].round(0)} per month " \
    "over the past #{savings_data[:months_analyzed]} months (3-month analysis). " \
    "Consider investing $#{suggested_amount.round(0)} per month starting " \
    "#{(@reference_date + 1.month).beginning_of_month.strftime('%B %d')}. " \
    "This would leave $#{(savings_data[:average_monthly_savings] - suggested_amount).round(0)} for expenses " \
    "while building your investment portfolio."
  end

  # Legacy methods kept for backwards compatibility
  def generate_savings_opportunity_message(savings_opp, income, spending, savings)
    generate_savings_only_message(savings_opp, income, spending, savings)
  end

  def generate_investment_message(savings_data, suggested_amount)
    generate_investment_only_message(savings_data, suggested_amount)
  end

  def generate_category_merchant_message(item, trend, view_type)
    trend_text = trend[:direction] == "up" ? "increased" : trend[:direction] == "down" ? "decreased" : "stayed consistent"
    "Your top #{view_type} is #{item[:name]} with $#{item[:amount].round(0)} spent across #{item[:count]} transactions. " \
    "Spending has #{trend_text} #{trend[:percentage].abs}% compared to last month." \
    "#{trend[:direction] == 'up' ? ' Consider reviewing these transactions.' : ''}"
  end

  def generate_day_of_week_message(day_name, day_info, monthly_frequency, overall_avg)
    pct_higher = ((day_info[:average] - overall_avg) / overall_avg * 100).round(0)
    "You spend an average of $#{day_info[:average].round(0)} per transaction on #{day_name}s, " \
    "which is #{pct_higher}% higher than your overall average of $#{overall_avg.round(0)} per transaction (3-month analysis). " \
    "This pattern occurs approximately #{monthly_frequency} times per month. " \
    "Consider reviewing your #{day_name} spending habits to identify potential savings opportunities."
  end

  def generate_merchant_habit_message(merchant_name, merchant_info, monthly_frequency, monthly_total, months_analyzed)
    suggested_frequency = (monthly_frequency * 0.6).round(1)
    potential_savings = (monthly_total * 0.4).round(0)

    "You've made #{merchant_info[:count]} transactions at #{merchant_name} over the past #{months_analyzed.round(0)} months, " \
    "averaging #{monthly_frequency} times per month at $#{merchant_info[:average].round(0)} per transaction. " \
    "This amounts to approximately $#{monthly_total.round(0)} per month. " \
    "If you reduced visits from #{monthly_frequency} to #{suggested_frequency} times per month, you could save approximately $#{potential_savings} monthly. " \
    "Consider meal planning or bulk shopping as alternatives."
  end

  def generate_budget_coach_title(budget_plan)
    overspend_amount = budget_plan[:projected_savings].abs
    if overspend_amount > 500
      "Budget Plan to Stay on Track"
    elsif overspend_amount > 100
      "Budget Plan to Stay on Track"
    else
      "Budget Plan Based on Expected Income"
    end
  end

  def generate_budget_coach_message(budget_plan)
    overspend_amount = budget_plan[:projected_savings].abs
    income = budget_plan[:current_month_income]
    projected = budget_plan[:projected_spending]
    target = budget_plan[:target_spending]
    savings_goal = budget_plan[:savings_goal]
    category_budgets = budget_plan[:category_budgets]

    # Build category budget list
    category_list = category_budgets.first(3).map do |budget|
      "#{budget[:category]}: $#{budget[:weekly_target]}/week"
    end.join(", ")

    if overspend_amount > 100
      # Overspending scenario
      base_message = "To get back on track this month, here's a realistic budget plan based on your spending history: #{category_list}. "

      if category_budgets.length > 3
        base_message += "Additional categories: #{category_budgets[3..-1].map { |b| "#{b[:category]}: $#{b[:weekly_target]}/week" }.join(", ")}. "
      end

      base_message += "This would reduce your projected spending from $#{projected.round(0)} to $#{target.round(0)}, "

      if savings_goal > 0
        base_message += "allowing you to save $#{savings_goal.round(0)} by month-end."
      else
        base_message += "keeping you within your income of $#{income.round(0)}."
      end
    else
      # Close to limit scenario
      base_message = "Based on your income pattern, you're expecting $#{income.round(0)} this month. "
      base_message += "To maximize savings, try: #{category_list}. "

      if savings_goal > 0
        base_message += "This would allow you to save $#{savings_goal.round(0)} this month."
      else
        base_message += "This would keep you within your budget."
      end
    end

    base_message
  end

  def calculate_current_month_income
    month_start = @reference_date.beginning_of_month
    month_end = @reference_date.end_of_month
    @account.transactions
            .real
            .income
            .where(transaction_date: month_start..month_end)
            .sum(:amount)
            .abs
  end

  def analyze_recent_savings(months)
    monthly_breakdown = []
    total_savings = 0.0

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
      monthly_breakdown << {
        month: month_date.strftime("%B %Y"),
        income: income,
        expenses: expenses,
        savings: savings
      }
      total_savings += savings
    end

    avg_savings = total_savings / months.to_f
    consistent = monthly_breakdown.all? { |m| m[:savings] > 0 } && avg_savings > 100

    {
      months_analyzed: months,
      average_monthly_savings: avg_savings,
      monthly_breakdown: monthly_breakdown.reverse,
      consistent_savings: consistent
    }
  end

  def get_top_categories
    month_start = @reference_date.beginning_of_month
    month_end = @reference_date.end_of_month

    @account.transactions
            .real
            .expenses
            .where(transaction_date: month_start..month_end)
            .where.not(category: [ nil, "" ])
            .group(:category)
            .select("category, SUM(amount) as total, COUNT(*) as count")
            .order("total ASC")
            .limit(5)
            .map do |cat|
              {
                name: cat.category || "Uncategorized",
                amount: cat.total.abs,
                count: cat.count
              }
            end
  end

  def get_top_merchants
    TransactionMerchantService.call(
      @account,
      "expense",
      @reference_date.beginning_of_month,
      @reference_date.end_of_month,
      limit: 5
    ).map do |merchant|
      {
        name: merchant[:merchant] || "Unknown",
        amount: merchant[:total],
        count: merchant[:count]
      }
    end
  end

  def calculate_trend_for_item(item, view_type)
    current_month = @reference_date.beginning_of_month..@reference_date.end_of_month
    last_month = (@reference_date - 1.month).beginning_of_month..(@reference_date - 1.month).end_of_month

    current_amount = if view_type == "merchant"
                       @account.transactions
                               .real
                               .expenses
                               .where(transaction_date: current_month)
                               .where(merchant: item[:name])
                               .sum(:amount)
                               .abs
    else
                       @account.transactions
                               .real
                               .expenses
                               .where(transaction_date: current_month)
                               .where(category: item[:name])
                               .sum(:amount)
                               .abs
    end

    last_month_amount = if view_type == "merchant"
                          @account.transactions
                                  .real
                                  .expenses
                                  .where(transaction_date: last_month)
                                  .where(merchant: item[:name])
                                  .sum(:amount)
                                  .abs
    else
                          @account.transactions
                                  .real
                                  .expenses
                                  .where(transaction_date: last_month)
                                  .where(category: item[:name])
                                  .sum(:amount)
                                  .abs
    end

    return { direction: "stable", percentage: 0 } if last_month_amount.zero?

    change_pct = ((current_amount - last_month_amount) / last_month_amount * 100).round(1)
    direction = change_pct > 5 ? "up" : change_pct < -5 ? "down" : "stable"

    {
      direction: direction,
      percentage: change_pct,
      current_amount: current_amount,
      last_month_amount: last_month_amount
    }
  end

  def priority_weight(priority)
    case priority
    when "high" then 3
    when "medium" then 2
    when "low" then 1
    else 0
    end
  end

  # Contextual display logic
  def determine_context
    day_of_month = @reference_date.day
    days_in_month = @reference_date.end_of_month.day

    # Determine time of month: early (1-10), mid (11-20), late (21-end)
    period = if day_of_month <= 10
      :early_month
    elsif day_of_month <= 20
      :mid_month
    else
      :late_month
    end

    # Check for upcoming recurring expenses
    upcoming_recurring = check_upcoming_recurring_expenses

    {
      period: period,
      day_of_month: day_of_month,
      days_remaining: days_in_month - day_of_month,
      upcoming_recurring: upcoming_recurring
    }
  end

  def should_show_savings_insight?(context)
    # Show savings insights more prominently in late month (when users can act on them)
    # Also show in early/mid month for planning
    true # Always show for now, can be refined
  end

  def should_show_pattern_insights?(context)
    # Show pattern insights in mid-to-late month when users have more transaction data
    # Avoid showing in very early month (day 1-5) when data is limited
    context[:day_of_month] > 5
  end

  def check_upcoming_recurring_expenses
    # Check for recurring expenses in the next 7 days
    next_week = @reference_date..(@reference_date + 7.days)

    @account.transactions
            .real
            .expenses
            .from_recurring
            .where(transaction_date: next_week)
            .exists?
  end
end
