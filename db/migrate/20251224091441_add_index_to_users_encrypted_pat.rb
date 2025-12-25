class AddIndexToUsersEncryptedPat < ActiveRecord::Migration[8.1]
  def change
    # Index for checking presence (optional, for performance)
    # Only add if it doesn't exist
    unless index_exists?(:users, :up_pat_ciphertext, name: "index_users_on_encrypted_pat_presence")
      add_index :users, :up_pat_ciphertext,
        where: "up_pat_ciphertext IS NOT NULL",
        name: "index_users_on_encrypted_pat_presence"
    end
  end
end
