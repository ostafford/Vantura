class AddAccessLevelToProjectMemberships < ActiveRecord::Migration[7.0]
  def change
    add_column :project_memberships, :access_level, :integer, null: false, default: 0
  end
end


