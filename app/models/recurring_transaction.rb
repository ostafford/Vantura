class RecurringTransaction < ApplicationRecord
  # Associations
  belongs_to :account
  belongs_to :template_transaction, class_name: 'Transaction', optional: true
  has_many :generated_transactions, class_name: 'Transaction', foreign_key: 'recurring_transaction_id', dependent: :nullify

  # Validations
  validates :description, presence: true
  validates :amount, presence: true, numericality: true
  validates :frequency, presence: true
  validates :next_occurrence_date, presence: true
  validates :transaction_type, presence: true
  validates :is_active, inclusion: { in: [true, false] }

  # Enums
  enum :frequency, {
    weekly: 'weekly',
    fortnightly: 'fortnightly',
    monthly: 'monthly',
    quarterly: 'quarterly',
    yearly: 'yearly'
  }, prefix: true

  enum :transaction_type, {
    income: 'income',
    expense: 'expense'
  }, prefix: true

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :income_transactions, -> { where(transaction_type: 'income') }
  scope :expense_transactions, -> { where(transaction_type: 'expense') }
  scope :due_soon, ->(days = 7) { where('next_occurrence_date <= ?', Date.today + days.days) }
  
  # Methods
  def calculate_next_occurrence(from_date = next_occurrence_date)
    case frequency
    when 'weekly'
      from_date + 1.week
    when 'fortnightly'
      from_date + 2.weeks
    when 'monthly'
      from_date + 1.month
    when 'quarterly'
      from_date + 3.months
    when 'yearly'
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
end
