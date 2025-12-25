class CreateTransactionTags < ActiveRecord::Migration[8.1]
  def change
    create_table :transaction_tags do |t|
      t.bigint :transaction_id, null: false
      t.bigint :tag_id, null: false
      t.timestamps
    end

    add_index :transaction_tags, :transaction_id
    add_index :transaction_tags, :tag_id
    add_index :transaction_tags, [:transaction_id, :tag_id], unique: true, name: "index_transaction_tags_unique"
    add_foreign_key :transaction_tags, :transactions
    add_foreign_key :transaction_tags, :tags
  end
end
