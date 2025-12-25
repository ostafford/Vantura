class TransactionTag < ApplicationRecord
  belongs_to :transaction_record, class_name: "Transaction", foreign_key: "transaction_id"
  belongs_to :tag

  validates :transaction_id, uniqueness: { scope: :tag_id }
end

