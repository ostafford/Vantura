class TransactionCategory < ApplicationRecord
  belongs_to :transaction_record, class_name: "Transaction", foreign_key: "transaction_id"
  belongs_to :category

  validates :transaction_id, uniqueness: { scope: :category_id }
end

