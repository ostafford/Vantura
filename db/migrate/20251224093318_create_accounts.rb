class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.bigint :user_id, null: false
      t.string :up_id, null: false
      t.string :account_type, null: false
      t.string :ownership_type, null: false
      t.string :display_name
      t.decimal :balance, precision: 10, scale: 2, null: false
      t.string :currency_code, default: "AUD"
      t.datetime :up_created_at
      t.timestamps
    end

    add_index :accounts, :user_id
    add_index :accounts, :up_id, unique: true
    add_index :accounts, [:user_id, :account_type], name: "index_accounts_on_user_and_type"
    add_foreign_key :accounts, :users
  end
end
