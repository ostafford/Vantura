class RecurringCategory < ApplicationRecord
  # Associations
  belongs_to :account
  # Note: has_many relationship is not directly defined because recurring_category is stored as string
  # The relationship is handled through the recurring_category string field on RecurringTransaction

  # Validations
  validates :name, presence: true
  validates :transaction_type, presence: true, inclusion: { in: %w[income expense] }
  validates :name, uniqueness: { scope: [ :account_id, :transaction_type ], case_sensitive: false }

  # Scopes
  scope :for_account, ->(account) { where(account_id: account.id) }
  scope :for_transaction_type, ->(type) { where(transaction_type: type) }

  # Pre-defined categories that cannot be deleted
  PREDEFINED_INCOME = %w[salary freelance investment rental other].freeze
  PREDEFINED_EXPENSE = %w[subscription bill loan insurance other].freeze

  def predefined?
    case transaction_type
    when "income"
      PREDEFINED_INCOME.include?(name.downcase)
    when "expense"
      PREDEFINED_EXPENSE.include?(name.downcase)
    else
      false
    end
  end

  def self.predefined_for_type(type)
    case type
    when "income"
      PREDEFINED_INCOME
    when "expense"
      PREDEFINED_EXPENSE
    else
      []
    end
  end
end
