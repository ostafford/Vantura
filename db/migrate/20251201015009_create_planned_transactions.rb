class CreatePlannedTransactions < ActiveRecord::Migration[8.0]
  def change
    unless table_exists?(:planned_transactions)
      create_table :planned_transactions do |t|
        t.references :user, null: false, foreign_key: true
        t.integer :transaction_id
        t.date :planned_date
        t.integer :amount_cents
        t.string :amount_currency
        t.string :description
        t.string :transaction_type
        t.integer :category_id
        t.boolean :is_recurring
        t.text :recurrence_rule

        t.timestamps
      end
      add_foreign_key :planned_transactions, :transactions unless foreign_key_exists?(:planned_transactions, :transactions)
      add_foreign_key :planned_transactions, :categories unless foreign_key_exists?(:planned_transactions, :categories)
      add_index :planned_transactions, [:user_id, :planned_date] unless index_exists?(:planned_transactions, [:user_id, :planned_date])
      add_index :planned_transactions, :transaction_id unless index_exists?(:planned_transactions, :transaction_id)
    else
      add_foreign_key :planned_transactions, :transactions unless foreign_key_exists?(:planned_transactions, :transactions)
      add_foreign_key :planned_transactions, :categories unless foreign_key_exists?(:planned_transactions, :categories)
      add_index :planned_transactions, [:user_id, :planned_date] unless index_exists?(:planned_transactions, [:user_id, :planned_date])
      add_index :planned_transactions, :transaction_id unless index_exists?(:planned_transactions, :transaction_id)
    end
  end
end
