class CreateAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :accounts do |t|
      t.string :up_account_id
      t.string :display_name
      t.string :account_type
      t.decimal :current_balance, precision: 10, scale: 2
      t.datetime :last_synced_at

      t.timestamps
    end
  end
end
