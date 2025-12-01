class CreateExpenseContributions < ActiveRecord::Migration[8.0]
  def change
    create_table :expense_contributions, if_not_exists: true do |t|
      t.references :project_expense, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :amount_cents
      t.string :amount_currency
      t.datetime :paid_at
      t.references :paid_via_transaction, null: true, foreign_key: { to_table: :transactions }

      t.timestamps
    end
  end
end
