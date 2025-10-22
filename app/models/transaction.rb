class Transaction < ApplicationRecord
  include Turbo::Broadcastable

  # Associations
  belongs_to :account
  belongs_to :recurring_transaction, optional: true

  # Validations
  validates :description, presence: true
  validates :amount, presence: true, numericality: true
  validates :transaction_date, presence: true
  validates :status, presence: true
  validates :is_hypothetical, inclusion: { in: [ true, false ] }

  # Broadcast dashboard updates after creating/updating transactions
  after_create_commit :broadcast_dashboard_update
  after_update_commit :broadcast_dashboard_update
  after_destroy_commit :broadcast_dashboard_update

  # Scopes for common queries
  scope :real, -> { where(is_hypothetical: false) }
  scope :hypothetical, -> { where(is_hypothetical: true) }
  scope :expenses, -> { where("amount < 0") }
  scope :income, -> { where("amount > 0") }
  scope :for_date, ->(date) { where(transaction_date: date) }
  scope :for_month, ->(date) { where(transaction_date: date.beginning_of_month..date.end_of_month) }
  scope :from_recurring, -> { where.not(recurring_transaction_id: nil) }

  # Enums for status
  enum :status, {
    held: "HELD",
    settled: "SETTLED",
    hypothetical: "HYPOTHETICAL"
  }, prefix: true

  # Check if this is a recurring transaction (generated or real matched)
  def recurring?
    recurring_transaction_id.present?
  end

  # Determine the transaction type based on amount
  # @return [String] "expense" or "income"
  def transaction_type
    return "expense" if amount.nil? # Default for new transactions
    amount < 0 ? "expense" : "income"
  end

  private

  # Broadcast dashboard updates to the user's channel using Turbo Streams
  def broadcast_dashboard_update
    return unless account&.user # Ensure we have a user to broadcast to

    # Calculate updated stats using service
    stats = DashboardStatsCalculator.call(account)

    current_date = stats[:current_date]
    expense_count = stats[:expense_count]
    expense_total = stats[:expense_total]
    income_count = stats[:income_count]
    income_total = stats[:income_total]
    end_of_month_balance = stats[:end_of_month_balance]

    # Broadcast Turbo Stream updates to user's channel
    broadcast_replace_to(
      account.user,
      target: "expenses_card",
      partial: "dashboard/expenses_card",
      locals: {
        expense_total: expense_total,
        expense_count: expense_count,
        current_date: current_date
      }
    )

    broadcast_replace_to(
      account.user,
      target: "income_card",
      partial: "dashboard/income_card",
      locals: {
        income_total: income_total,
        income_count: income_count,
        current_date: current_date
      }
    )

    broadcast_replace_to(
      account.user,
      target: "projection_card",
      partial: "dashboard/projection_card",
      locals: {
        income_total: income_total,
        expense_total: expense_total,
        end_of_month_balance: end_of_month_balance
      }
    )
  end
end
