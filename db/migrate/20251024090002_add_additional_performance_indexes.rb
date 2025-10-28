class AddAdditionalPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Add index for filters by user and creation date (for recent scope)
    add_index :filters, [ :user_id, :created_at ], name: "index_filters_on_user_id_and_created_at"

    # Add indexes for transactions by merchant and category (for filtering)
    add_index :transactions, [ :merchant, :category ], name: "index_transactions_on_merchant_and_category"

    # Add index for transactions by status and date (for filtering)
    add_index :transactions, [ :status, :transaction_date ], name: "index_transactions_on_status_and_date"

    # Add index for transactions by category (for grouping)
    add_index :transactions, :category, name: "index_transactions_on_category"

    # Add index for transactions by merchant (for grouping)
    add_index :transactions, :merchant, name: "index_transactions_on_merchant"
  end
end
