class RecurringTransaction < ApplicationRecord
  # Associations
  belongs_to :account
  belongs_to :template_transaction, class_name: "Transaction", optional: true
  has_many :generated_transactions, class_name: "Transaction", foreign_key: "recurring_transaction_id", dependent: :destroy

  # Validations
  validates :description, presence: true
  validates :amount, presence: true, numericality: true
  validates :frequency, presence: true
  validates :next_occurrence_date, presence: true
  validates :transaction_type, presence: true
  validates :is_active, inclusion: { in: [ true, false ] }

  # Enums
  enum :frequency, {
    weekly: "weekly",
    fortnightly: "fortnightly",
    monthly: "monthly",
    quarterly: "quarterly",
    yearly: "yearly"
  }, prefix: true

  enum :transaction_type, {
    income: "income",
    expense: "expense"
  }, prefix: true

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :income_transactions, -> { where(transaction_type: "income") }
  scope :expense_transactions, -> { where(transaction_type: "expense") }
  scope :due_soon, ->(days = 7) { where("next_occurrence_date <= ?", Date.today + days.days) }

  # Methods
  # Return upcoming recurring transactions for an account up to end_date, split by type
  # and with precomputed totals.
  def self.upcoming_for_account(account, end_date = Date.today.end_of_month)
    upcoming = account.recurring_transactions
                      .active
                      .where("next_occurrence_date <= ?", end_date)
                      .order(:next_occurrence_date)

    expenses = upcoming.select { |r| r.transaction_type_expense? }
    income = upcoming.select { |r| r.transaction_type_income? }

    {
      expenses: expenses,
      income: income,
      expense_total: expenses.sum { |r| r.amount.abs },
      income_total: income.sum { |r| r.amount }
    }
  end
  def calculate_next_occurrence(from_date = next_occurrence_date)
    case frequency
    when "weekly"
      from_date + 1.week
    when "fortnightly"
      from_date + 2.weeks
    when "monthly"
      from_date + 1.month
    when "quarterly"
      from_date + 3.months
    when "yearly"
      from_date + 1.year
    end
  end

  def matches_transaction?(transaction)
    return false unless merchant_pattern.present?

    # Check if merchant/description contains the pattern (case insensitive)
    description_match = transaction.description.downcase.include?(merchant_pattern.downcase)

    # Check if amount is within tolerance
    amount_match = (transaction.amount.abs - amount.abs).abs <= (amount_tolerance || 1.0)

    description_match && amount_match
  end

  # Extract merchant pattern from transaction description
  # Removes common noise like numbers and reference codes
  # @param description [String] The transaction description
  # @return [String] Extracted merchant pattern (first 1-2 significant words)
  def self.extract_merchant_pattern(description)
    return "" if description.blank?

    # Remove common patterns like numbers, dates, reference codes
    pattern = description.gsub(/\d{4,}/, "") # Remove long numbers (e.g., transaction IDs)
                        .gsub(/\s+\d+$/, "")  # Remove trailing numbers
                        .strip

    # Take the first significant word(s) as the pattern
    words = pattern.split
    words.first(2).join(" ") # Use first 1-2 words as pattern
  end
end
