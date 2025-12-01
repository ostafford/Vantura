class FixTransactionUniquenessConstraint < ActiveRecord::Migration[8.0]
  def up
    # Remove the global unique index
    remove_index :transactions, :up_id if index_exists?(:transactions, :up_id)

    # Add composite unique index matching model validation
    add_index :transactions, [ :up_id, :user_id ], unique: true,
              name: 'index_transactions_on_up_id_and_user_id'
  end

  def down
    remove_index :transactions, name: 'index_transactions_on_up_id_and_user_id'
    add_index :transactions, :up_id, unique: true
  end
end
