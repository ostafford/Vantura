class AddProjectColor < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :color, :string, if_not_exists: true
  end
end
