class AddIncomeTypeToRecurringTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :recurring_transactions, :income_type, :string
  end
end
