class AddRecurringCategoryToRecurringTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :recurring_transactions, :recurring_category, :string
    add_index :recurring_transactions, :recurring_category
  end
end
