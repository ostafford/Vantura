class CreatePlannedTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :planned_transactions, if_not_exists: true do |t|
      t.references :user, null: false, foreign_key: true
      t.references :transaction, null: true, foreign_key: true
      t.date :planned_date
      t.integer :amount_cents
      t.string :amount_currency
      t.string :description
      t.string :transaction_type
      t.references :category, null: true, foreign_key: true
      t.boolean :is_recurring
      t.text :recurrence_rule

      t.timestamps
    end
    # Foreign keys now handled by t.references above
    add_index :planned_transactions, [ :user_id, :planned_date ], if_not_exists: true
    add_index :planned_transactions, :transaction_id, if_not_exists: true
  end
end
