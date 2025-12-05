class AddNotesToTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :transactions, :notes, :text
  end
end
