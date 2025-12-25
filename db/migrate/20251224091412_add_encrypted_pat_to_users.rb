class AddEncryptedPatToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :up_pat_ciphertext, :text
    add_column :users, :last_synced_at, :datetime

    # Index for checking presence (optional, for performance)
    add_index :users, :up_pat_ciphertext,
      where: "up_pat_ciphertext IS NOT NULL",
      name: "index_users_on_encrypted_pat_presence"
  end
end
