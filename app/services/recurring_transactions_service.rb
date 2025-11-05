# Service Object: Get upcoming recurring transactions
#
# Usage:
#   data = RecurringTransactionsService.upcoming(@account, end_date)
#   data = RecurringTransactionsService.upcoming(@account, Date.today.end_of_month)
#
# Returns hash with:
#   - expenses: Array of expense recurring transactions
#   - income: Array of income recurring transactions
#   - expense_total: Sum of expense amounts
#   - income_total: Sum of income amounts
#
class RecurringTransactionsService < ApplicationService
  def self.upcoming(account, end_date)
    new(account, end_date).call
  end

  def initialize(account, end_date)
    @account = account
    @end_date = end_date
  end

  def call
    {
      expenses: expenses,
      income: income,
      expense_total: expense_total,
      income_total: income_total
    }
  end

  private

  def upcoming_recurring
    @upcoming_recurring ||= @account.recurring_transactions
                                     .active
                                     .where("next_occurrence_date <= ?", @end_date)
                                     .order(:next_occurrence_date)
                                     .to_a
  end

  def expenses
    @expenses ||= upcoming_recurring.select { |r| r.transaction_type_expense? }
  end

  def income
    @income ||= upcoming_recurring.select { |r| r.transaction_type_income? }
  end

  def expense_total
    @expense_total ||= expenses.sum { |r| r.amount.abs }
  end

  def income_total
    @income_total ||= income.sum { |r| r.amount }
  end
end
