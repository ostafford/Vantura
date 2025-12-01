class CreateFeedbackItems < ActiveRecord::Migration[8.0]
  def change
    create_table :feedback_items, if_not_exists: true do |t|
      t.references :user, null: false, foreign_key: true
      t.string :feedback_type
      t.string :status, default: "new"
      t.text :description

      t.timestamps
    end
    add_index :feedback_items, [ :user_id, :status ], if_not_exists: true
  end
end
