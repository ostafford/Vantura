# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_12_01_061159) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "up_id"
    t.string "account_type"
    t.string "display_name"
    t.integer "balance_cents"
    t.string "balance_currency"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "ownership_type"
    t.datetime "created_at_up"
    t.index ["up_id", "user_id"], name: "index_accounts_on_up_id_and_user_id", unique: true
    t.index ["user_id"], name: "index_accounts_on_user_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name"
    t.bigint "parent_id"
    t.string "icon"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "up_id"
    t.index ["up_id"], name: "index_categories_on_up_id", unique: true, where: "(up_id IS NOT NULL)"
  end

  create_table "expense_contributions", force: :cascade do |t|
    t.bigint "project_expense_id", null: false
    t.bigint "user_id", null: false
    t.integer "amount_cents"
    t.string "amount_currency"
    t.datetime "paid_at"
    t.bigint "paid_via_transaction_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status", default: "pending"
    t.text "note"
    t.index ["paid_via_transaction_id"], name: "index_expense_contributions_on_paid_via_transaction_id"
    t.index ["project_expense_id"], name: "index_expense_contributions_on_project_expense_id"
    t.index ["user_id"], name: "index_expense_contributions_on_user_id"
  end

  create_table "feedback_items", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "feedback_type"
    t.string "status", default: "new"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "status"], name: "index_feedback_items_on_user_id_and_status"
    t.index ["user_id"], name: "index_feedback_items_on_user_id"
  end

  create_table "filters", force: :cascade do |t|
    t.string "name"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "filter_params"
    t.jsonb "filter_types"
    t.jsonb "date_range"
    t.index ["filter_params"], name: "index_filters_on_filter_params", using: :gin
    t.index ["filter_types"], name: "index_filters_on_filter_types", using: :gin
    t.index ["user_id", "created_at"], name: "index_filters_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_filters_on_user_id"
  end

  create_table "goals", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name"
    t.string "goal_type"
    t.integer "target_amount_cents"
    t.string "period"
    t.date "start_date"
    t.date "end_date"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "active"], name: "index_goals_on_user_id_and_active"
    t.index ["user_id"], name: "index_goals_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "notification_type", null: false
    t.string "title", null: false
    t.text "message", null: false
    t.datetime "read_at"
    t.text "metadata"
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active", "created_at"], name: "index_notifications_on_is_active_and_created_at"
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at"
    t.index ["user_id", "notification_type"], name: "index_notifications_on_user_id_and_notification_type"
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_id_and_read_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "planned_transactions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "transaction_id"
    t.date "planned_date"
    t.integer "amount_cents"
    t.string "amount_currency"
    t.string "description"
    t.string "transaction_type"
    t.bigint "category_id"
    t.boolean "is_recurring", default: false
    t.text "recurrence_rule"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.string "recurrence_pattern"
    t.date "recurrence_end_date"
    t.index ["category_id"], name: "index_planned_transactions_on_category_id"
    t.index ["transaction_id"], name: "index_planned_transactions_on_transaction_id"
    t.index ["user_id", "planned_date"], name: "index_planned_transactions_on_user_id_and_planned_date"
    t.index ["user_id"], name: "index_planned_transactions_on_user_id"
  end

  create_table "project_expenses", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "transaction_id"
    t.string "description"
    t.integer "total_amount_cents"
    t.string "total_amount_currency"
    t.date "expense_date"
    t.bigint "category_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.bigint "paid_by_user_id"
    t.index ["category_id"], name: "index_project_expenses_on_category_id"
    t.index ["paid_by_user_id"], name: "index_project_expenses_on_paid_by_user_id"
    t.index ["project_id", "expense_date"], name: "index_project_expenses_on_project_id_and_expense_date"
    t.index ["project_id"], name: "index_project_expenses_on_project_id"
    t.index ["transaction_id"], name: "index_project_expenses_on_transaction_id"
  end

  create_table "project_members", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "user_id", null: false
    t.string "role"
    t.boolean "can_create"
    t.boolean "can_edit"
    t.boolean "can_delete"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "user_id"], name: "index_project_members_on_project_id_and_user_id", unique: true
    t.index ["project_id"], name: "index_project_members_on_project_id"
    t.index ["user_id"], name: "index_project_members_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.bigint "owner_id", null: false
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "color"
    t.index ["owner_id"], name: "index_projects_on_owner_id"
  end

  create_table "recurring_transactions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "description"
    t.decimal "amount", precision: 10, scale: 2
    t.string "frequency"
    t.date "next_occurrence_date"
    t.boolean "is_active"
    t.string "transaction_type"
    t.string "category"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "template_transaction_id"
    t.string "merchant_pattern"
    t.decimal "amount_tolerance", precision: 10, scale: 2, default: "1.0"
    t.string "projection_months", default: "indefinite"
    t.index ["account_id", "is_active"], name: "idx_recurring_account_active"
    t.index ["account_id"], name: "index_recurring_transactions_on_account_id"
    t.index ["template_transaction_id"], name: "index_recurring_transactions_on_template_transaction_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_active_at"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  create_table "transaction_tags", force: :cascade do |t|
    t.bigint "transaction_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tag_id"], name: "index_transaction_tags_on_tag_id"
    t.index ["transaction_id", "tag_id"], name: "index_transaction_tags_on_transaction_id_and_tag_id", unique: true
    t.index ["transaction_id"], name: "index_transaction_tags_on_transaction_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "account_id", null: false
    t.string "up_id"
    t.string "status"
    t.text "raw_text"
    t.string "description"
    t.text "message"
    t.integer "amount_cents"
    t.string "amount_currency"
    t.integer "foreign_amount_cents"
    t.string "foreign_amount_currency"
    t.datetime "settled_at"
    t.jsonb "hold_info"
    t.string "card_purchase_method"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "category_id"
    t.datetime "created_at_up"
    t.boolean "is_categorizable", default: true
    t.integer "round_up_cents"
    t.integer "cashback_cents"
    t.index ["account_id"], name: "index_transactions_on_account_id"
    t.index ["category_id"], name: "index_transactions_on_category_id"
    t.index ["status"], name: "index_transactions_on_status"
    t.index ["up_id", "user_id"], name: "index_transactions_on_up_id_and_user_id", unique: true
    t.index ["user_id", "created_at"], name: "index_transactions_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_transactions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "encrypted_password", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "up_bank_token_encrypted"
    t.text "up_bank_token_encrypted_iv"
    t.text "up_bank_token_encrypted_salt"
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.boolean "admin", default: false, null: false
    t.string "name"
    t.string "avatar_url"
    t.boolean "dark_mode", default: false
    t.string "currency", default: "AUD"
    t.datetime "last_synced_at"
    t.index ["admin"], name: "index_users_on_admin"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "webhook_events", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "event_type"
    t.jsonb "payload"
    t.datetime "processed_at"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "up_event_id"
    t.index ["event_type"], name: "index_webhook_events_on_event_type"
    t.index ["user_id", "processed_at"], name: "index_webhook_events_on_user_id_and_processed_at"
    t.index ["user_id"], name: "index_webhook_events_on_user_id"
  end

  add_foreign_key "accounts", "users"
  add_foreign_key "expense_contributions", "project_expenses"
  add_foreign_key "expense_contributions", "transactions", column: "paid_via_transaction_id"
  add_foreign_key "expense_contributions", "users"
  add_foreign_key "feedback_items", "users"
  add_foreign_key "filters", "users"
  add_foreign_key "goals", "users"
  add_foreign_key "notifications", "users"
  add_foreign_key "planned_transactions", "categories"
  add_foreign_key "planned_transactions", "transactions"
  add_foreign_key "planned_transactions", "users"
  add_foreign_key "project_expenses", "categories"
  add_foreign_key "project_expenses", "projects"
  add_foreign_key "project_expenses", "transactions"
  add_foreign_key "project_expenses", "users", column: "paid_by_user_id"
  add_foreign_key "project_members", "projects"
  add_foreign_key "project_members", "users"
  add_foreign_key "projects", "users", column: "owner_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "transaction_tags", "tags"
  add_foreign_key "transaction_tags", "transactions"
  add_foreign_key "transactions", "accounts"
  add_foreign_key "transactions", "categories"
  add_foreign_key "transactions", "users"
  add_foreign_key "webhook_events", "users"
end
