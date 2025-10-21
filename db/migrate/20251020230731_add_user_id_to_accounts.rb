class AddUserIdToAccounts < ActiveRecord::Migration[8.0]
  def change
    # Add user_id column as nullable first
    add_reference :accounts, :user, null: true, foreign_key: true

    # Note: In production, you would create a default user and assign existing accounts to it
    # For development, we'll just make it nullable
  end
end
