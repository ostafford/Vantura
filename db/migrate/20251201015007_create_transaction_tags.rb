class CreateTransactionTags < ActiveRecord::Migration[8.0]
  def change
    create_table :transaction_tags, if_not_exists: true do |t|
      t.references :transaction, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end
  end
end
