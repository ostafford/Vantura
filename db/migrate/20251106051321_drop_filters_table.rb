class DropFiltersTable < ActiveRecord::Migration[8.0]
  def change
    remove_foreign_key :filters, :users, if_exists: true
    drop_table :filters, if_exists: true
  end
end
