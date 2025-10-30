class CreateExpenseContributions < ActiveRecord::Migration[7.0]
  def change
    create_table :expense_contributions do |t|
      t.references :project_expense, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :share_cents, null: false, default: 0
      t.boolean :paid, null: false, default: false
      t.datetime :paid_at

      t.timestamps
    end

    add_index :expense_contributions, [ :project_expense_id, :user_id ], unique: true, name: "index_contributions_on_expense_and_user"
  end
end
