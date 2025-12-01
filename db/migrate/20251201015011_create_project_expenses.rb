class CreateProjectExpenses < ActiveRecord::Migration[8.0]
  def change
    unless table_exists?(:project_expenses)
      create_table :project_expenses do |t|
        t.references :project, null: false, foreign_key: true
        t.integer :transaction_id
        t.string :description
        t.integer :total_amount_cents
        t.string :total_amount_currency
        t.date :expense_date
        t.integer :category_id

        t.timestamps
      end
      add_foreign_key :project_expenses, :transactions unless foreign_key_exists?(:project_expenses, :transactions)
      add_foreign_key :project_expenses, :categories unless foreign_key_exists?(:project_expenses, :categories)
      add_index :project_expenses, [:project_id, :expense_date] unless index_exists?(:project_expenses, [:project_id, :expense_date])
    else
      add_foreign_key :project_expenses, :transactions unless foreign_key_exists?(:project_expenses, :transactions)
      add_foreign_key :project_expenses, :categories unless foreign_key_exists?(:project_expenses, :categories)
      add_index :project_expenses, [:project_id, :expense_date] unless index_exists?(:project_expenses, [:project_id, :expense_date])
    end
  end
end
