class CreateTransactionCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :transaction_categories do |t|
      t.bigint :transaction_id, null: false
      t.bigint :category_id, null: false
      t.timestamps
    end

    add_index :transaction_categories, :transaction_id
    add_index :transaction_categories, :category_id
    add_index :transaction_categories, [:transaction_id, :category_id], unique: true, name: "index_transaction_categories_unique"
    add_foreign_key :transaction_categories, :transactions
    add_foreign_key :transaction_categories, :categories
  end
end
