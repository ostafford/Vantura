class CreateTransactions < ActiveRecord::Migration[8.0]
  def change
    unless table_exists?(:transactions)
      create_table :transactions do |t|
        t.references :user, null: false, foreign_key: true
        t.references :account, null: false, foreign_key: true
        t.string :up_id
        t.string :status
        t.text :raw_text
        t.string :description
        t.text :message
        t.integer :amount_cents
        t.string :amount_currency
        t.integer :foreign_amount_cents
        t.string :foreign_amount_currency
        t.datetime :settled_at
        t.jsonb :hold_info
        t.string :card_purchase_method
        t.datetime :created_at

        t.timestamps
      end
      add_index :transactions, :up_id, unique: true unless index_exists?(:transactions, :up_id)
      add_index :transactions, [:user_id, :created_at] unless index_exists?(:transactions, [:user_id, :created_at])
      add_index :transactions, :status unless index_exists?(:transactions, :status)
    else
      add_index :transactions, :up_id, unique: true unless index_exists?(:transactions, :up_id)
      add_index :transactions, [:user_id, :created_at] unless index_exists?(:transactions, [:user_id, :created_at])
      add_index :transactions, :status unless index_exists?(:transactions, :status)
    end
  end
end
