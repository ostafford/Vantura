class CreateBudgetAlerts < ActiveRecord::Migration[8.1]
  def change
    create_table :budget_alerts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :budget, null: false, foreign_key: true
      t.decimal :spent, precision: 10, scale: 2
      t.decimal :limit, precision: 10, scale: 2
      t.decimal :percentage, precision: 5, scale: 2

      t.timestamps
    end

    add_index :budget_alerts, [:user_id, :budget_id, :created_at]
  end
end
