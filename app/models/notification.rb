class Notification < ApplicationRecord
  # Associations
  belongs_to :user

  # Enums
  enum :notification_type, {
    transaction_created: "transaction_created",
    transaction_settled: "transaction_settled",
    large_transaction: "large_transaction",
    goal_progress: "goal_progress",
    goal_achieved: "goal_achieved",
    project_expense_added: "project_expense_added",
    project_expense_paid: "project_expense_paid",
    sync_completed: "sync_completed",
    sync_failed: "sync_failed",
    recurring_detected: "recurring_detected",
    system: "system"
  }

  # Validations
  validates :user_id, presence: true
  validates :notification_type, presence: true
  validates :title, presence: true
  validates :message, presence: true

  # Scopes
  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }
  scope :by_type, ->(type) { where(notification_type: type) }

  # Instance methods
  def read?
    read_at.present?
  end

  def unread?
    !read?
  end

  def mark_as_read!
    update!(read_at: Time.current) unless read?
  end

  def mark_as_unread!
    update!(read_at: nil) if read?
  end

  def deactivate!
    update!(is_active: false)
  end

  def activate!
    update!(is_active: true)
  end

  # Parse metadata JSON if stored as text
  def metadata_hash
    return {} if metadata.blank?
    JSON.parse(metadata)
  rescue JSON::ParserError
    {}
  end

  def metadata_hash=(hash)
    self.metadata = hash.to_json
  end

  # Class methods for creating notifications
  def self.create_transaction_notification(user, transaction, type: :transaction_created)
    create!(
      user: user,
      notification_type: type,
      title: "Transaction #{type.to_s.humanize}",
      message: "Transaction: #{transaction.description} - #{transaction.amount.format}",
      metadata_hash: {
        transaction_id: transaction.id,
        transaction_up_id: transaction.up_id,
        amount_cents: transaction.amount_cents
      }
    )
  end

  def self.create_large_transaction_notification(user, transaction, threshold_cents: 100_000)
    create!(
      user: user,
      notification_type: :large_transaction,
      title: "Large Transaction Alert",
      message: "A large transaction of #{transaction.amount.format} was detected: #{transaction.description}",
      metadata_hash: {
        transaction_id: transaction.id,
        transaction_up_id: transaction.up_id,
        amount_cents: transaction.amount_cents,
        threshold_cents: threshold_cents
      }
    )
  end

  def self.create_sync_notification(user, success: true, transaction_count: 0, error_message: nil)
    if success
      create!(
        user: user,
        notification_type: :sync_completed,
        title: "Sync Completed",
        message: "Successfully synced #{transaction_count} new transaction#{transaction_count != 1 ? 's' : ''}",
        metadata_hash: {
          transaction_count: transaction_count,
          synced_at: Time.current.iso8601
        }
      )
    else
      create!(
        user: user,
        notification_type: :sync_failed,
        title: "Sync Failed",
        message: "Failed to sync transactions: #{error_message || 'Unknown error'}",
        metadata_hash: {
          error_message: error_message,
          failed_at: Time.current.iso8601
        }
      )
    end
  end

  def self.create_goal_notification(user, goal, type: :goal_progress)
    create!(
      user: user,
      notification_type: type,
      title: "Goal #{type.to_s.humanize}",
      message: "Goal '#{goal.name}' - #{goal.goal_type.humanize}",
      metadata_hash: {
        goal_id: goal.id,
        goal_type: goal.goal_type,
        target_amount_cents: goal.target_amount_cents
      }
    )
  end

  def self.create_project_notification(user, project, expense, type: :project_expense_added)
    create!(
      user: user,
      notification_type: type,
      title: "Project Expense #{type.to_s.humanize}",
      message: "Expense '#{expense.name || expense.description}' added to project '#{project.name}'",
      metadata_hash: {
        project_id: project.id,
        expense_id: expense.id
      }
    )
  end

  def self.mark_all_as_read_for_user(user)
    where(user: user, read_at: nil).update_all(read_at: Time.current)
  end
end
