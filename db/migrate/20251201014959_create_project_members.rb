class CreateProjectMembers < ActiveRecord::Migration[8.0]
  def change
    create_table :project_members, if_not_exists: true do |t|
      t.references :project, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role
      t.boolean :can_create
      t.boolean :can_edit
      t.boolean :can_delete

      t.timestamps
    end
  end
end
