class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Critical performance indexes for transaction queries
    # These indexes will dramatically improve query performance for:
    # - Dashboard stats calculations
    # - Calendar view queries
    # - Transaction filtering by date ranges

    add_index :transactions, :transaction_date, name: 'idx_transactions_date'
    add_index :transactions, [ :account_id, :transaction_date ], name: 'idx_transactions_account_date'
    add_index :transactions, [ :recurring_transaction_id, :transaction_date ], name: 'idx_transactions_recurring_date'

    # Additional performance indexes for common query patterns
    add_index :transactions, [ :account_id, :status ], name: 'idx_transactions_account_status'
    add_index :transactions, [ :transaction_date, :amount ], name: 'idx_transactions_date_amount'

    # Index for recurring transaction queries
    add_index :recurring_transactions, [ :account_id, :is_active ], name: 'idx_recurring_account_active'
  end
end
