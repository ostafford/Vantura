class MigrateIncomeTypeToRecurringCategory < ActiveRecord::Migration[8.0]
  def up
    execute <<-SQL
      UPDATE recurring_transactions
      SET recurring_category = income_type
      WHERE income_type IS NOT NULL AND transaction_type = 'income'
    SQL
  end

  def down
    execute <<-SQL
      UPDATE recurring_transactions
      SET income_type = recurring_category
      WHERE recurring_category IS NOT NULL AND transaction_type = 'income'
    SQL
  end
end
