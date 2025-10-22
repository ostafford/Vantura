class AddUniqueIndexToAccountsUpAccountId < ActiveRecord::Migration[8.0]
  def change
    add_index :accounts, :up_account_id, unique: true
  end
end
