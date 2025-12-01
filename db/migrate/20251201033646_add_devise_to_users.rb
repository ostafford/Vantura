class AddDeviseToUsers < ActiveRecord::Migration[8.0]
  def up
    # Rename password_digest to encrypted_password (Devise standard)
    if column_exists?(:users, :password_digest) && !column_exists?(:users, :encrypted_password)
      rename_column :users, :password_digest, :encrypted_password
    end
    
    # Add Devise columns if they don't exist
    add_column :users, :reset_password_token, :string unless column_exists?(:users, :reset_password_token)
    add_column :users, :reset_password_sent_at, :datetime unless column_exists?(:users, :reset_password_sent_at)
    add_column :users, :remember_created_at, :datetime unless column_exists?(:users, :remember_created_at)
    
    # Add indexes
    add_index :users, :reset_password_token, unique: true unless index_exists?(:users, :reset_password_token)
  end
  
  def down
    # Reverse the changes
    remove_index :users, :reset_password_token if index_exists?(:users, :reset_password_token)
    remove_column :users, :remember_created_at if column_exists?(:users, :remember_created_at)
    remove_column :users, :reset_password_sent_at if column_exists?(:users, :reset_password_sent_at)
    remove_column :users, :reset_password_token if column_exists?(:users, :reset_password_token)
    
    if column_exists?(:users, :encrypted_password) && !column_exists?(:users, :password_digest)
      rename_column :users, :encrypted_password, :password_digest
    end
  end
end
