class CreateAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :accounts, if_not_exists: true do |t|
      t.references :user, null: false, foreign_key: true
      t.string :up_id
      t.string :account_type
      t.string :display_name
      t.integer :balance_cents
      t.string :balance_currency

      t.timestamps
    end
    # Note: Global unique index on up_id removed in later migration
    # Replaced with composite unique index [:up_id, :user_id] to match model validation
    add_index :accounts, :up_id, unique: true, if_not_exists: true
    add_index :accounts, :user_id, if_not_exists: true
  end
end
