class CreateTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :transactions do |t|
      t.bigint :user_id, null: false
      t.bigint :account_id, null: false
      t.string :up_id, null: false
      t.string :status, null: false
      t.string :raw_text
      t.text :description
      t.string :message
      t.boolean :hold_info_is_cover, default: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :currency_code, default: "AUD"
      t.string :foreign_amount
      t.string :foreign_currency_code
      t.datetime :settled_at
      t.datetime :up_created_at
      t.timestamps
    end

    add_index :transactions, :user_id
    add_index :transactions, :account_id
    add_index :transactions, [:up_id, :user_id], unique: true, name: "index_transactions_on_up_id_and_user_id"
    add_index :transactions, :status
    add_index :transactions, :settled_at
    add_index :transactions, [:user_id, :settled_at], name: "index_transactions_on_user_and_settled"
    add_foreign_key :transactions, :users
    add_foreign_key :transactions, :accounts
  end
end
