class RemoveIncomeTypeFromRecurringTransactions < ActiveRecord::Migration[8.0]
  def change
    remove_column :recurring_transactions, :income_type, :string
  end
end
