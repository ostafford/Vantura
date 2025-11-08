class ChangeDefaultAmountToleranceToRecurringTransactions < ActiveRecord::Migration[8.0]
  def up
    # Change default value for new records
    change_column_default :recurring_transactions, :amount_tolerance, 5.0

    # Update existing records with nil tolerance to 5.0
    execute <<-SQL
      UPDATE recurring_transactions
      SET amount_tolerance = 5.0
      WHERE amount_tolerance IS NULL
    SQL
  end

  def down
    change_column_default :recurring_transactions, :amount_tolerance, 1.0
  end
end
