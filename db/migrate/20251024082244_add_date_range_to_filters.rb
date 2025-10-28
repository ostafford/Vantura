class AddDateRangeToFilters < ActiveRecord::Migration[8.0]
  def change
    add_column :filters, :date_range, :text
  end
end
