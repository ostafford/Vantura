class AddMatchingFieldsToRecurringTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :recurring_transactions, :template_transaction_id, :integer
    add_column :recurring_transactions, :merchant_pattern, :string
    add_column :recurring_transactions, :amount_tolerance, :decimal, precision: 10, scale: 2, default: 1.0

    add_index :recurring_transactions, :template_transaction_id
    add_foreign_key :recurring_transactions, :transactions, column: :template_transaction_id
  end
end
