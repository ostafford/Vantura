class CreateTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :transactions do |t|
      t.references :account, null: false, foreign_key: true
      t.string :up_transaction_id
      t.string :description
      t.string :merchant
      t.decimal :amount, precision: 10, scale: 2
      t.string :category
      t.date :transaction_date
      t.string :status
      t.boolean :is_hypothetical
      t.datetime :settled_at

      t.timestamps
    end
  end
end
