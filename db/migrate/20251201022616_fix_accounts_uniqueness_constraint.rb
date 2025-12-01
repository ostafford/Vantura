class FixAccountsUniquenessConstraint < ActiveRecord::Migration[8.0]
  def change
    # Remove the global unique index on up_id
    remove_index :accounts, :up_id, if_exists: true

    # Add composite unique index matching model validation (uniqueness: { scope: :user_id })
    add_index :accounts, [ :up_id, :user_id ], unique: true, if_not_exists: true
  end
end
