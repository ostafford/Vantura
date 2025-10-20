class AddRecurringTransactionIdToTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :transactions, :recurring_transaction_id, :integer
    add_index :transactions, :recurring_transaction_id
    add_foreign_key :transactions, :recurring_transactions
  end
end
