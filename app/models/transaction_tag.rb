class TransactionTag < ApplicationRecord
  # Uses 'transaction_record' instead of 'transaction' to avoid conflict with
  # ActiveRecord's transaction method (used for database transactions)
  # Reference: https://guides.rubyonrails.org/active_record_basics.html
  belongs_to :transaction_record, class_name: "Transaction", foreign_key: "transaction_id"
  belongs_to :tag

  validates :transaction_id, uniqueness: { scope: :tag_id }
end
