class AddSavingsGoalsToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :target_savings_rate, :decimal,
               precision: 5,
               scale: 4,
               null: false,
               default: 0.0

    add_column :accounts, :target_savings_amount, :decimal,
               precision: 12,
               scale: 2,
               null: true

    add_column :accounts, :goal_last_set_at, :datetime

    add_index :accounts, :goal_last_set_at
  end
end
