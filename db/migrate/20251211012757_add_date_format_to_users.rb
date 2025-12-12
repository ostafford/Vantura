class AddDateFormatToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :date_format, :string, default: "DD/MM/YYYY"
  end
end
