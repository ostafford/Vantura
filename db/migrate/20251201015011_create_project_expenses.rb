class CreateProjectExpenses < ActiveRecord::Migration[8.0]
  def change
    create_table :project_expenses, if_not_exists: true do |t|
      t.references :project, null: false, foreign_key: true
      t.integer :transaction_id
      t.string :description
      t.integer :total_amount_cents
      t.string :total_amount_currency
      t.date :expense_date
      t.integer :category_id

      t.timestamps
    end
    add_foreign_key :project_expenses, :transactions, if_not_exists: true
    add_foreign_key :project_expenses, :categories, if_not_exists: true
    add_index :project_expenses, [ :project_id, :expense_date ], if_not_exists: true
  end
end
