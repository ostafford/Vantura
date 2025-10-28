class RemoveUnusedFilterTypeColumn < ActiveRecord::Migration[8.0]
  def change
    remove_column :filters, :filter_type, :string
  end
end
