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

ActiveRecord::Schema[8.0].define(version: 2025_10_24_090002) do
  create_table "accounts", force: :cascade do |t|
    t.string "up_account_id"
    t.string "display_name"
    t.string "account_type"
    t.decimal "current_balance", precision: 10, scale: 2
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["up_account_id"], name: "index_accounts_on_up_account_id", unique: true
    t.index ["user_id"], name: "index_accounts_on_user_id"
  end

  create_table "filters", force: :cascade do |t|
    t.string "name"
    t.text "filter_params"
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "filter_types"
    t.text "date_range"
    t.index ["user_id", "created_at"], name: "index_filters_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_filters_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.integer "user_id", null: false
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

  create_table "recurring_transactions", force: :cascade do |t|
    t.integer "account_id", null: false
    t.string "description"
    t.decimal "amount", precision: 10, scale: 2
    t.string "frequency"
    t.date "next_occurrence_date"
    t.boolean "is_active"
    t.string "transaction_type"
    t.string "category"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "template_transaction_id"
    t.string "merchant_pattern"
    t.decimal "amount_tolerance", precision: 10, scale: 2, default: "1.0"
    t.string "projection_months", default: "indefinite"
    t.index ["account_id", "is_active"], name: "idx_recurring_account_active"
    t.index ["account_id"], name: "index_recurring_transactions_on_account_id"
    t.index ["template_transaction_id"], name: "index_recurring_transactions_on_template_transaction_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_active_at"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.integer "account_id", null: false
    t.string "up_transaction_id"
    t.string "description"
    t.string "merchant"
    t.decimal "amount", precision: 10, scale: 2
    t.string "category"
    t.date "transaction_date"
    t.string "status"
    t.boolean "is_hypothetical"
    t.datetime "settled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "recurring_transaction_id"
    t.index ["account_id", "status"], name: "idx_transactions_account_status"
    t.index ["account_id", "transaction_date"], name: "idx_transactions_account_date"
    t.index ["account_id"], name: "index_transactions_on_account_id"
    t.index ["category"], name: "index_transactions_on_category"
    t.index ["merchant", "category"], name: "index_transactions_on_merchant_and_category"
    t.index ["merchant"], name: "index_transactions_on_merchant"
    t.index ["recurring_transaction_id", "transaction_date"], name: "idx_transactions_recurring_date"
    t.index ["recurring_transaction_id"], name: "index_transactions_on_recurring_transaction_id"
    t.index ["status", "transaction_date"], name: "index_transactions_on_status_and_date"
    t.index ["transaction_date", "amount"], name: "idx_transactions_date_amount"
    t.index ["transaction_date"], name: "idx_transactions_date"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "up_bank_token"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "accounts", "users"
  add_foreign_key "filters", "users"
  add_foreign_key "notifications", "users"
  add_foreign_key "recurring_transactions", "accounts"
  add_foreign_key "recurring_transactions", "transactions", column: "template_transaction_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "transactions", "accounts"
  add_foreign_key "transactions", "recurring_transactions"
end
