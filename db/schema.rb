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

ActiveRecord::Schema[8.1].define(version: 2025_12_25_005000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "account_type", null: false
    t.decimal "balance", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.string "currency_code", default: "AUD"
    t.string "display_name"
    t.string "ownership_type", null: false
    t.datetime "up_created_at"
    t.string "up_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["up_id"], name: "index_accounts_on_up_id", unique: true
    t.index ["user_id", "account_type"], name: "index_accounts_on_user_and_type"
    t.index ["user_id"], name: "index_accounts_on_user_id"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "budget_alerts", force: :cascade do |t|
    t.bigint "budget_id", null: false
    t.datetime "created_at", null: false
    t.decimal "limit", precision: 10, scale: 2
    t.decimal "percentage", precision: 5, scale: 2
    t.decimal "spent", precision: 10, scale: 2
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["budget_id"], name: "index_budget_alerts_on_budget_id"
    t.index ["user_id", "budget_id", "created_at"], name: "index_budget_alerts_on_user_id_and_budget_id_and_created_at"
    t.index ["user_id"], name: "index_budget_alerts_on_user_id"
  end

  create_table "budgets", force: :cascade do |t|
    t.boolean "active", default: true
    t.decimal "alert_threshold", precision: 5, scale: 2, default: "80.0"
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.bigint "category_id"
    t.datetime "created_at", null: false
    t.date "end_date"
    t.string "name", null: false
    t.string "period", default: "monthly"
    t.date "start_date"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["category_id"], name: "index_budgets_on_category_id"
    t.index ["user_id", "active"], name: "index_budgets_on_user_and_active"
    t.index ["user_id"], name: "index_budgets_on_user_id"
  end

  create_table "categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "parent_id"
    t.string "up_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_categories_on_parent_id"
    t.index ["up_id"], name: "index_categories_on_up_id", unique: true
  end

  create_table "expense_contributions", force: :cascade do |t|
    t.integer "amount_cents"
    t.string "amount_currency"
    t.datetime "created_at", null: false
    t.text "note"
    t.datetime "paid_at"
    t.bigint "paid_via_transaction_id"
    t.bigint "project_expense_id", null: false
    t.string "status", default: "pending"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["paid_via_transaction_id"], name: "index_expense_contributions_on_paid_via_transaction_id"
    t.index ["project_expense_id"], name: "index_expense_contributions_on_project_expense_id"
    t.index ["user_id"], name: "index_expense_contributions_on_user_id"
  end

  create_table "feedback_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "feedback_type"
    t.string "status", default: "new"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "status"], name: "index_feedback_items_on_user_id_and_status"
    t.index ["user_id"], name: "index_feedback_items_on_user_id"
  end

  create_table "filters", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "date_range"
    t.jsonb "filter_params"
    t.jsonb "filter_types"
    t.string "name"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["filter_params"], name: "index_filters_on_filter_params", using: :gin
    t.index ["filter_types"], name: "index_filters_on_filter_types", using: :gin
    t.index ["user_id", "created_at"], name: "index_filters_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_filters_on_user_id"
  end

  create_table "goals", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.date "end_date"
    t.string "goal_type"
    t.string "name"
    t.string "period"
    t.date "start_date"
    t.integer "target_amount_cents"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "active"], name: "index_goals_on_user_id_and_active"
    t.index ["user_id"], name: "index_goals_on_user_id"
  end

  create_table "investment_goals", force: :cascade do |t|
    t.bigint "account_id"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.decimal "current_amount", precision: 10, scale: 2, default: "0.0"
    t.text "description"
    t.string "name", null: false
    t.decimal "target_amount", precision: 10, scale: 2, null: false
    t.date "target_date"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["account_id"], name: "index_investment_goals_on_account_id"
    t.index ["user_id"], name: "index_investment_goals_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_active", default: true, null: false
    t.text "message", null: false
    t.text "metadata"
    t.string "notification_type", null: false
    t.datetime "read_at"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["is_active", "created_at"], name: "index_notifications_on_is_active_and_created_at"
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at"
    t.index ["user_id", "notification_type"], name: "index_notifications_on_user_id_and_notification_type"
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_id_and_read_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "planned_transactions", force: :cascade do |t|
    t.integer "amount_cents"
    t.string "amount_currency"
    t.bigint "category_id"
    t.datetime "created_at", null: false
    t.string "description"
    t.boolean "is_recurring", default: false
    t.string "name"
    t.date "planned_date"
    t.date "recurrence_end_date"
    t.string "recurrence_pattern"
    t.text "recurrence_rule"
    t.bigint "transaction_id"
    t.string "transaction_type"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["category_id"], name: "index_planned_transactions_on_category_id"
    t.index ["transaction_id"], name: "index_planned_transactions_on_transaction_id"
    t.index ["user_id", "planned_date"], name: "index_planned_transactions_on_user_id_and_planned_date"
    t.index ["user_id"], name: "index_planned_transactions_on_user_id"
  end

  create_table "project_expenses", force: :cascade do |t|
    t.bigint "category_id"
    t.datetime "created_at", null: false
    t.string "description"
    t.date "expense_date"
    t.string "name"
    t.bigint "paid_by_user_id"
    t.bigint "project_id", null: false
    t.integer "total_amount_cents"
    t.string "total_amount_currency"
    t.bigint "transaction_id"
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_project_expenses_on_category_id"
    t.index ["paid_by_user_id"], name: "index_project_expenses_on_paid_by_user_id"
    t.index ["project_id", "expense_date"], name: "index_project_expenses_on_project_id_and_expense_date"
    t.index ["project_id"], name: "index_project_expenses_on_project_id"
    t.index ["transaction_id"], name: "index_project_expenses_on_transaction_id"
  end

  create_table "project_members", force: :cascade do |t|
    t.boolean "can_create"
    t.boolean "can_delete"
    t.boolean "can_edit"
    t.datetime "created_at", null: false
    t.bigint "project_id", null: false
    t.string "role"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["project_id", "user_id"], name: "index_project_members_on_project_id_and_user_id", unique: true
    t.index ["project_id"], name: "index_project_members_on_project_id"
    t.index ["user_id"], name: "index_project_members_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "color"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.bigint "owner_id", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_projects_on_owner_id"
  end

  create_table "recurring_transactions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.decimal "amount", precision: 10, scale: 2
    t.decimal "amount_tolerance", precision: 10, scale: 2, default: "1.0"
    t.string "category"
    t.datetime "created_at", null: false
    t.string "description"
    t.string "frequency"
    t.boolean "is_active"
    t.string "merchant_pattern"
    t.date "next_occurrence_date"
    t.string "projection_months", default: "indefinite"
    t.bigint "template_transaction_id"
    t.string "transaction_type"
    t.datetime "updated_at", null: false
    t.index ["account_id", "is_active"], name: "idx_recurring_account_active"
    t.index ["account_id"], name: "index_recurring_transactions_on_account_id"
    t.index ["template_transaction_id"], name: "index_recurring_transactions_on_template_transaction_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "last_active_at"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "name"], name: "index_tags_on_user_and_name", unique: true
    t.index ["user_id"], name: "index_tags_on_user_id"
  end

  create_table "transaction_categories", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.bigint "transaction_id", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_transaction_categories_on_category_id"
    t.index ["transaction_id", "category_id"], name: "index_transaction_categories_unique", unique: true
    t.index ["transaction_id"], name: "index_transaction_categories_on_transaction_id"
  end

  create_table "transaction_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "tag_id", null: false
    t.bigint "transaction_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tag_id"], name: "index_transaction_tags_on_tag_id"
    t.index ["transaction_id", "tag_id"], name: "index_transaction_tags_unique", unique: true
    t.index ["transaction_id"], name: "index_transaction_tags_on_transaction_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.string "currency_code", default: "AUD"
    t.text "description"
    t.string "foreign_amount"
    t.string "foreign_currency_code"
    t.boolean "hold_info_is_cover", default: false
    t.string "message"
    t.string "raw_text"
    t.datetime "settled_at"
    t.string "status", null: false
    t.datetime "up_created_at"
    t.string "up_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["account_id"], name: "index_transactions_on_account_id"
    t.index ["settled_at"], name: "index_transactions_on_settled_at"
    t.index ["status"], name: "index_transactions_on_status"
    t.index ["up_id", "user_id"], name: "index_transactions_on_up_id_and_user_id", unique: true
    t.index ["user_id", "settled_at"], name: "index_transactions_on_user_and_settled"
    t.index ["user_id"], name: "index_transactions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "last_synced_at"
    t.datetime "locked_at"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.text "up_pat_ciphertext"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["up_pat_ciphertext"], name: "index_users_on_encrypted_pat_presence", where: "(up_pat_ciphertext IS NOT NULL)"
  end

  create_table "webhook_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "event_type"
    t.jsonb "payload"
    t.datetime "processed_at"
    t.string "up_event_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["event_type"], name: "index_webhook_events_on_event_type"
    t.index ["user_id", "processed_at"], name: "index_webhook_events_on_user_id_and_processed_at"
    t.index ["user_id"], name: "index_webhook_events_on_user_id"
  end

  add_foreign_key "accounts", "users"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "budget_alerts", "budgets"
  add_foreign_key "budget_alerts", "users"
  add_foreign_key "budgets", "categories"
  add_foreign_key "budgets", "users"
  add_foreign_key "expense_contributions", "project_expenses"
  add_foreign_key "investment_goals", "accounts"
  add_foreign_key "investment_goals", "users"
  add_foreign_key "project_expenses", "projects"
  add_foreign_key "project_members", "projects"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "tags", "users"
  add_foreign_key "transaction_categories", "categories"
  add_foreign_key "transaction_categories", "transactions"
  add_foreign_key "transaction_tags", "tags"
  add_foreign_key "transaction_tags", "transactions"
  add_foreign_key "transactions", "accounts"
  add_foreign_key "transactions", "users"
end
