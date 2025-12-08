class RemoveAttrEncryptedColumnsFromUsers < ActiveRecord::Migration[8.0]
  def up
    # Verify new column exists before removing old ones
    unless column_exists?(:users, :up_bank_token_ciphertext)
      raise "Cannot remove old columns: up_bank_token_ciphertext column must exist first"
    end

    # Remove old attr_encrypted columns
    remove_column :users, :up_bank_token_encrypted, :text if column_exists?(:users, :up_bank_token_encrypted)
    remove_column :users, :up_bank_token_encrypted_iv, :text if column_exists?(:users, :up_bank_token_encrypted_iv)
    remove_column :users, :up_bank_token_encrypted_salt, :text if column_exists?(:users, :up_bank_token_encrypted_salt)
  end

  def down
    # Rollback: re-add old columns (data will be lost)
    add_column :users, :up_bank_token_encrypted, :text unless column_exists?(:users, :up_bank_token_encrypted)
    add_column :users, :up_bank_token_encrypted_iv, :text unless column_exists?(:users, :up_bank_token_encrypted_iv)
    add_column :users, :up_bank_token_encrypted_salt, :text unless column_exists?(:users, :up_bank_token_encrypted_salt)
  end
end
