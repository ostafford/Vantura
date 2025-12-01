class CreateProjectExpenses < ActiveRecord::Migration[8.0]
  def change
    create_table :project_expenses, if_not_exists: true do |t|
      t.references :project, null: false, foreign_key: true
      t.references :transaction, null: true, foreign_key: true
      t.string :description
      t.integer :total_amount_cents
      t.string :total_amount_currency
      t.date :expense_date
      t.references :category, null: true, foreign_key: true

      t.timestamps
    end
    # Foreign keys now handled by t.references above
    add_index :project_expenses, [ :project_id, :expense_date ], if_not_exists: true
  end
end
