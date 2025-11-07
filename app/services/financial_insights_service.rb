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

    # Only generate insight if there's a significant change (>10%)
    return nil if change_pct.abs < 10

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
            potential_savings: savings_opp[:potential_savings]
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
          historical_monthly_avg: (historical[:average_daily_rate] * 30.44).round(2)
        },
        suggested_action: "Review Spending",
        suggested_amount: nil,
        suggested_date: nil,
        priority: "medium"
      }
    end
  end

  # Calculate potential savings opportunity
  def savings_opportunity_insight
    savings_opp = @velocity_calculator.savings_opportunity(6)
    return nil unless savings_opp[:opportunity_exists]

    current_month_income = calculate_current_month_income
    projected_spending = @velocity_calculator.projected_month_end_spending[:projected_total]
    projected_savings = current_month_income - projected_spending

    {
      type: "savings_opportunity",
      title: "Savings Opportunity Detected",
      message: generate_savings_opportunity_message(savings_opp, current_month_income, projected_spending, projected_savings),
      evidence: {
        current_income: current_month_income,
        projected_spending: projected_spending,
        projected_savings: projected_savings,
        potential_additional_savings: savings_opp[:potential_savings],
        historical_average_spending: savings_opp[:historical_average],
        current_velocity: @velocity_calculator.current_velocity[:daily_rate]
      },
      suggested_action: "Create Savings Transfer",
      suggested_amount: savings_opp[:potential_savings],
      suggested_date: @reference_date.end_of_month,
      priority: "high"
    }
  end

  # Suggest investment amounts based on consistent savings
  def investment_suggestion
    # Analyze last 3 months of savings
    savings_data = analyze_recent_savings(3)
    return nil unless savings_data[:consistent_savings]

    avg_monthly_savings = savings_data[:average_monthly_savings]
    suggested_investment = (avg_monthly_savings * 0.5).round(2) # Suggest investing 50% of average savings

    # Only suggest if amount is meaningful (>$50)
    return nil if suggested_investment < 50

    {
      type: "investment_suggestion",
      title: "Consider Starting Regular Investments",
      message: generate_investment_message(savings_data, suggested_investment),
      evidence: {
        months_analyzed: savings_data[:months_analyzed],
        average_monthly_savings: avg_monthly_savings,
        monthly_savings_breakdown: savings_data[:monthly_breakdown],
        suggested_monthly_investment: suggested_investment,
        remaining_for_expenses: (avg_monthly_savings - suggested_investment).round(2)
      },
      suggested_action: "Set Up Investment Plan",
      suggested_amount: suggested_investment,
      suggested_date: (@reference_date + 1.month).beginning_of_month,
      priority: "medium"
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

  # Generate all insights (top 2-3 for dashboard)
  def generate_key_insights(limit = 3)
    insights = []

    # Priority order: velocity > savings opportunity > investment > category/merchant
    insights << spending_velocity_insight
    insights << savings_opportunity_insight
    insights << investment_suggestion
    insights << category_merchant_insight

    # Filter out nil, sort by priority, limit
    insights.compact
            .sort_by { |i| priority_weight(i[:priority]) }
            .reverse
            .first(limit)
  end

  private

  def generate_velocity_message(current, historical, change_pct, projected, savings_opp)
    "You're spending $#{current[:daily_rate]} per day, which is #{change_pct.abs}% " \
    "#{change_pct < 0 ? 'slower' : 'faster'} than your 6-month average of $#{historical[:average_daily_rate]} per day. " \
    "If you maintain this pace, you'll spend $#{projected[:projected_total].round(0)} this month, " \
    "compared to your average of $#{savings_opp[:historical_average].round(0)}. " \
    "This could result in $#{savings_opp[:potential_savings].round(0)} in additional savings. " \
    "Consider moving this amount to savings on #{@reference_date.end_of_month.strftime('%B %d')}."
  end

  def generate_velocity_warning_message(current, historical, change_pct, projected)
    "You're spending $#{current[:daily_rate]} per day, which is #{change_pct.abs}% faster than your " \
    "6-month average of $#{historical[:average_daily_rate]} per day. " \
    "At this pace, you're projected to spend $#{projected[:projected_total].round(0)} this month, " \
    "compared to your average of $#{(historical[:average_daily_rate] * 30.44).round(0)}. " \
    "Consider reviewing your recent transactions to identify areas where spending has increased."
  end

  def generate_savings_opportunity_message(savings_opp, income, spending, savings)
    "Based on your current spending velocity, you're on track to save $#{savings.round(0)} this month, " \
    "which is $#{savings_opp[:potential_savings].round(0)} more than your historical average. " \
    "Your income is $#{income.round(0)} and projected spending is $#{spending.round(0)}. " \
    "Consider setting up a hypothetical savings transfer of $#{savings_opp[:potential_savings].round(0)} " \
    "on #{@reference_date.end_of_month.strftime('%B %d')} to visualize the impact."
  end

  def generate_investment_message(savings_data, suggested_amount)
    "You've consistently saved an average of $#{savings_data[:average_monthly_savings].round(0)} per month " \
    "over the past #{savings_data[:months_analyzed]} months. " \
    "Consider investing $#{suggested_amount.round(0)} per month starting " \
    "#{(@reference_date + 1.month).beginning_of_month.strftime('%B %d')}. " \
    "This would leave $#{(savings_data[:average_monthly_savings] - suggested_amount).round(0)} for expenses " \
    "while building your investment portfolio."
  end

  def generate_category_merchant_message(item, trend, view_type)
    trend_text = trend[:direction] == "up" ? "increased" : trend[:direction] == "down" ? "decreased" : "stayed consistent"
    "Your top #{view_type} is #{item[:name]} with $#{item[:amount].round(0)} spent across #{item[:count]} transactions. " \
    "Spending has #{trend_text} #{trend[:percentage].abs}% compared to last month." \
    "#{trend[:direction] == 'up' ? ' Consider reviewing these transactions.' : ''}"
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
            .where.not(category: [nil, ""])
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
end

