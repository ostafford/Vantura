class AddUpBankTokenToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :up_bank_token_encrypted, :text unless column_exists?(:users, :up_bank_token_encrypted)
    add_column :users, :up_bank_token_encrypted_iv, :text unless column_exists?(:users, :up_bank_token_encrypted_iv)
    add_column :users, :up_bank_token_encrypted_salt, :text unless column_exists?(:users, :up_bank_token_encrypted_salt)
  end
end
