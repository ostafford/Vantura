class AddToleranceTypeToRecurringTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :recurring_transactions, :tolerance_type, :string, default: "fixed", null: false
    add_column :recurring_transactions, :tolerance_percentage, :decimal, precision: 5, scale: 2
  end
end
