class CreateAccounts < ActiveRecord::Migration[8.0]
  def change
    unless table_exists?(:accounts)
      create_table :accounts do |t|
        t.references :user, null: false, foreign_key: true
        t.string :up_id
        t.string :account_type
        t.string :display_name
        t.integer :balance_cents
        t.string :balance_currency

        t.timestamps
      end
      add_index :accounts, :up_id, unique: true unless index_exists?(:accounts, :up_id)
      add_index :accounts, :user_id unless index_exists?(:accounts, :user_id)
    else
      add_index :accounts, :up_id, unique: true unless index_exists?(:accounts, :up_id)
      add_index :accounts, :user_id unless index_exists?(:accounts, :user_id)
    end
  end
end
