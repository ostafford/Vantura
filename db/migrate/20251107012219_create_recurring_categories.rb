class CreateRecurringCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :recurring_categories do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :transaction_type, null: false

      t.timestamps
    end

    add_index :recurring_categories, :name
    add_index :recurring_categories, [:account_id, :name, :transaction_type], unique: true, name: "index_recurring_categories_unique"
  end
end
