class AddDateToleranceDaysToRecurringTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :recurring_transactions, :date_tolerance_days, :integer, default: 3, null: false
  end
end
