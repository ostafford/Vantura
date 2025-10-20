class Account < ApplicationRecord
  # Associations
  has_many :transactions, dependent: :destroy
  has_many :recurring_transactions, dependent: :destroy

  # Validations
  validates :up_account_id, presence: true, uniqueness: true
  validates :display_name, presence: true
  validates :account_type, presence: true
  validates :current_balance, presence: true, numericality: true

  # Enums for account types (matching Up Bank API)
  enum :account_type, {
    transactional: "TRANSACTIONAL",
    saver: "SAVER",
    home_loan: "HOME_LOAN"
  }, prefix: true

  # Calculate the projected balance at the end of a given month
  # @param date [Date] The date within the month to calculate for
  # @return [Float] The projected balance at the end of the month
  def end_of_month_balance(date = Date.today)
    today = Date.today
    month_end = date.end_of_month

    if month_end < today
      # For past months: current balance minus all transactions from month_end to today
      transactions_after_month = transactions
                                  .where("transaction_date > ? AND transaction_date <= ?",
                                         month_end, today)
      current_balance - transactions_after_month.sum(:amount)
    else
      # For current/future months: current balance plus all transactions from today to month_end
      transactions_until_month_end = transactions
                                      .where("transaction_date >= ? AND transaction_date <= ?",
                                             today, month_end)
      current_balance + transactions_until_month_end.sum(:amount)
    end
  end
end
