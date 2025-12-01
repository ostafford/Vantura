class AddPlannedTransactionFields < ActiveRecord::Migration[8.0]
  def change
    add_column :planned_transactions, :name, :string, if_not_exists: true
    add_column :planned_transactions, :recurrence_pattern, :string, if_not_exists: true
    add_column :planned_transactions, :recurrence_end_date, :date, if_not_exists: true
  end
end
