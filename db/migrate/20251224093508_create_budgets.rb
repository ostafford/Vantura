class CreateBudgets < ActiveRecord::Migration[8.1]
  def change
    create_table :budgets do |t|
      t.bigint :user_id, null: false
      t.bigint :category_id
      t.string :name, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :period, default: "monthly"
      t.date :start_date
      t.date :end_date
      t.decimal :alert_threshold, precision: 5, scale: 2, default: 80.0
      t.boolean :active, default: true
      t.timestamps
    end

    add_index :budgets, :user_id
    add_index :budgets, :category_id
    add_index :budgets, [:user_id, :active], name: "index_budgets_on_user_and_active"
    add_foreign_key :budgets, :users
    add_foreign_key :budgets, :categories
  end
end
