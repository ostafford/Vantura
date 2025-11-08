module RecurringTransactions
  class BreakdownService < ApplicationService
    def initialize(account)
      @account = account
    end

    def call
      # Get active recurring transactions
      active = @account.recurring_transactions.active

      # Calculate weekly breakdown
      week_breakdown = calculate_weekly_breakdown(active)

      # Calculate monthly breakdown
      month_breakdown = calculate_monthly_breakdown(active)

      # Get next occurrence
      next_occurrence = get_next_occurrence(active)

      {
        week_income: week_breakdown[:income],
        week_expenses: week_breakdown[:expenses],
        month_income: month_breakdown[:income],
        month_expenses: month_breakdown[:expenses],
        next_occurrence_date: next_occurrence[:date],
        next_occurrence_amount: next_occurrence[:amount],
        next_occurrence_desc: next_occurrence[:description]
      }
    end

    private

    def calculate_weekly_breakdown(active)
      week_start = Date.today.beginning_of_week(:monday)
      week_end = Date.today.end_of_week(:monday)

      # Get recurring transactions due this week
      week_recurring = active.where("next_occurrence_date <= ? AND next_occurrence_date >= ?", week_end, week_start)

      {
        income: week_recurring.where(transaction_type: "income").sum(:amount),
        expenses: week_recurring.where(transaction_type: "expense").sum(:amount).abs
      }
    end

    def calculate_monthly_breakdown(active)
      month_start = Date.today.beginning_of_month
      month_end = Date.today.end_of_month

      # Get recurring transactions due this month
      month_recurring = active.where("next_occurrence_date <= ? AND next_occurrence_date >= ?", month_end, month_start)

      {
        income: month_recurring.where(transaction_type: "income").sum(:amount),
        expenses: month_recurring.where(transaction_type: "expense").sum(:amount).abs
      }
    end

    def get_next_occurrence(active)
      next_occurrence = active.where("next_occurrence_date >= ?", Date.today).order(:next_occurrence_date).first

      {
        date: next_occurrence&.next_occurrence_date,
        amount: next_occurrence&.amount,
        description: next_occurrence&.description
      }
    end
  end
end
