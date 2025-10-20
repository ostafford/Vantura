class AddProjectionMonthsToRecurringTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :recurring_transactions, :projection_months, :string, default: 'indefinite'
  end
end
