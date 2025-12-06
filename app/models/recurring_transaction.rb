require "ice_cube"

class RecurringTransaction < ApplicationRecord
  belongs_to :account
  belongs_to :template_transaction, class_name: "Transaction", foreign_key: "template_transaction_id", optional: true

  # Enums
  enum :transaction_type, {
    expense: "expense",
    income: "income"
  }

  # Validations
  validates :account_id, presence: true
  validates :amount, presence: true
  validates :frequency, presence: true
  validates :next_occurrence_date, presence: true
  validates :transaction_type, presence: true

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :upcoming, -> { where("next_occurrence_date >= ?", Date.current) }
  scope :due, -> { active.where("next_occurrence_date <= ?", Date.current) }

  # Callbacks
  before_validation :set_defaults, on: :create
  before_validation :normalize_amount

  # Methods

  # Check if a transaction matches this recurring pattern
  def matches?(transaction)
    return false unless transaction.is_a?(Transaction)
    return false unless transaction.account_id == account_id

    # Check amount tolerance (for expenses, compare absolute values)
    expected_amount = transaction_type == "expense" ? amount.abs : amount
    actual_amount = transaction.amount_cents.abs / 100.0

    amount_difference = (expected_amount - actual_amount).abs
    return false if amount_difference > amount_tolerance

    # Check merchant/description pattern if present
    if merchant_pattern.present?
      return false unless transaction.description&.match?(/#{merchant_pattern}/i) ||
                          transaction.message&.match?(/#{merchant_pattern}/i)
    end

    # Check category if present
    if category.present? && transaction.category.present?
      return false unless transaction.category.name == category
    end

    true
  end

  # Generate planned transactions for a date range
  def generate_planned_transactions(start_date, end_date)
    return [] unless is_active?

    schedule = build_schedule
    return [] unless schedule

    planned_transactions = []
    occurrences = schedule.occurrences_between(start_date, end_date)

    occurrences.each do |occurrence_date|
      # Check if a planned transaction already exists for this date
      existing = PlannedTransaction.find_by(
        user: account.user,
        description: description,
        planned_date: occurrence_date,
        transaction_type: transaction_type
      )

      next if existing

      # Convert decimal amount to cents (amount is stored as decimal like 25.50)
      amount_cents = (amount.abs * 100).to_i
      # Make negative for expenses
      amount_cents = -amount_cents if transaction_type == "expense"

      planned_transaction = PlannedTransaction.create!(
        user: account.user,
        description: description,
        amount_cents: amount_cents,
        planned_date: occurrence_date,
        transaction_type: transaction_type,
        category: find_category
      )

      planned_transactions << planned_transaction
    end

    planned_transactions
  end

  # Calculate and update the next occurrence date
  def update_next_occurrence!
    schedule = build_schedule
    return false unless schedule

    next_occurrence = schedule.next_occurrence(next_occurrence_date || Date.current)
    if next_occurrence
      update_column(:next_occurrence_date, next_occurrence.to_date)
      true
    else
      false
    end
  end

  # Get all occurrences in a date range
  def occurrences(start_date, end_date)
    schedule = build_schedule
    return [] unless schedule

    schedule.occurrences_between(start_date, end_date)
  end

  # Build an IceCube schedule from the frequency string
  def build_schedule
    return nil if frequency.blank? || next_occurrence_date.blank?

    # Parse frequency string (e.g., "weekly", "monthly", "daily", "yearly")
    begin
      schedule = IceCube::Schedule.new(next_occurrence_date.to_time)

      case frequency.downcase.strip
      when "daily"
        schedule.add_recurrence_rule(IceCube::Rule.daily)
      when "weekly"
        schedule.add_recurrence_rule(IceCube::Rule.weekly)
      when "monthly"
        schedule.add_recurrence_rule(IceCube::Rule.monthly)
      when "yearly", "annually"
        schedule.add_recurrence_rule(IceCube::Rule.yearly)
      else
        Rails.logger.warn "RecurringTransaction#build_schedule: Unknown frequency '#{frequency}'"
        return nil
      end

      schedule
    rescue => e
      Rails.logger.error "RecurringTransaction#build_schedule error: #{e.message}"
      nil
    end
  end

  # Check if the recurring transaction is due today or overdue
  def due?
    return false unless is_active?
    next_occurrence_date <= Date.current
  end

  private

  def set_defaults
    self.is_active = true if is_active.nil?
    self.amount_tolerance ||= 1.0
    self.projection_months ||= "indefinite"
  end

  def normalize_amount
    # Ensure amount is positive or negative based on transaction_type
    if amount.present?
      if transaction_type == "expense" && amount > 0
        self.amount = -amount
      elsif transaction_type == "income" && amount < 0
        self.amount = amount.abs
      end
    end
  end

  def find_category
    return nil if category.blank?
    Category.find_by(name: category) || Category.find_by(up_id: category)
  end
end

