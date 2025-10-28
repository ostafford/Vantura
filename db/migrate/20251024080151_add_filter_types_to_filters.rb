class AddFilterTypesToFilters < ActiveRecord::Migration[8.0]
  def change
    add_column :filters, :filter_types, :text
  end
end
