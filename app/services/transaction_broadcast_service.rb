# Service Object: Broadcast dashboard updates when transactions change
#
# Usage:
#   TransactionBroadcastService.call(transaction)
#
# Broadcasts Turbo Stream updates to update dashboard cards in real-time
#
class TransactionBroadcastService < ApplicationService
  def initialize(transaction)
    @transaction = transaction
    @account = transaction.account
  end

  def call
    return unless @account&.user # Ensure we have a user to broadcast to

    # Calculate updated stats using service
    stats = DashboardStatsCalculator.call(@account)

    current_date = stats[:current_date]
    expense_count = stats[:expense_count]
    expense_total = stats[:expense_total]
    income_count = stats[:income_count]
    income_total = stats[:income_total]
    end_of_month_balance = stats[:end_of_month_balance]

    # Calculate upcoming recurring transactions for projection
    upcoming_recurring = get_upcoming_recurring_transactions
    upcoming_recurring_expenses = upcoming_recurring[:expenses]
    upcoming_recurring_income = upcoming_recurring[:income]
    upcoming_recurring_total = upcoming_recurring[:expense_total] + upcoming_recurring[:income_total]

    # Broadcast Turbo Stream updates to user's channel using transaction's broadcast methods
    @transaction.broadcast_replace_to(
      @account.user,
      target: "expenses_card",
      partial: "dashboard/transaction_type_card",
      locals: {
        type: "expense",
        expense_total: expense_total,
        expense_count: expense_count,
        current_date: current_date,
        top_expense_merchants: []
      }
    )

    @transaction.broadcast_replace_to(
      @account.user,
      target: "income_card",
      partial: "dashboard/transaction_type_card",
      locals: {
        type: "income",
        income_total: income_total,
        income_count: income_count,
        current_date: current_date,
        top_income_merchants: []
      }
    )

    @transaction.broadcast_replace_to(
      @account.user,
      target: "projection_card",
      partial: "dashboard/projection_card",
      locals: {
        income_total: income_total,
        expense_total: expense_total,
        end_of_month_balance: end_of_month_balance,
        current_date: current_date,
        upcoming_recurring_expenses: upcoming_recurring_expenses,
        upcoming_recurring_income: upcoming_recurring_income,
        upcoming_recurring_total: upcoming_recurring_total
      }
    )
  end

  private

  # Get upcoming recurring transactions for the rest of the month
  def get_upcoming_recurring_transactions
    end_of_month = Date.today.end_of_month

    upcoming = @account.recurring_transactions
                     .active
                     .where("next_occurrence_date <= ?", end_of_month)
                     .order(:next_occurrence_date)

    # Separate by type
    expenses = upcoming.select { |r| r.transaction_type_expense? }
    income = upcoming.select { |r| r.transaction_type_income? }

    {
      expenses: expenses,
      income: income,
      expense_total: expenses.sum { |r| r.amount.abs },
      income_total: income.sum { |r| r.amount }
    }
  end
end
