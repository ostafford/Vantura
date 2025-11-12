require "bigdecimal"

class Account < ApplicationRecord
  MAX_BALANCE = BigDecimal("99999999.99").freeze
  MIN_BALANCE = -MAX_BALANCE
  MAX_TARGET_SAVINGS_RATE = BigDecimal("0.3").freeze
  MIN_TARGET_SAVINGS_RATE = BigDecimal("0").freeze

  # Associations
  belongs_to :user, optional: true # Made optional for backward compatibility with existing data
  has_many :transactions, dependent: :destroy
  has_many :recurring_transactions, dependent: :destroy
  has_many :recurring_categories, dependent: :destroy
  has_many :financial_insights, dependent: :destroy

  # Validations
  validates :up_account_id, presence: true, uniqueness: true
  validates :display_name, presence: true
  validates :account_type, presence: true
  validates :current_balance,
            presence: true,
            numericality: {
              greater_than_or_equal_to: MIN_BALANCE,
              less_than_or_equal_to: MAX_BALANCE
            }
  validates :target_savings_rate,
            numericality: {
              greater_than_or_equal_to: MIN_TARGET_SAVINGS_RATE,
              less_than_or_equal_to: MAX_TARGET_SAVINGS_RATE
            }
  validates :target_savings_amount,
            numericality: {
              greater_than_or_equal_to: 0
            },
            allow_nil: true

  before_save :update_goal_timestamp, if: :goal_timestamp_update_required?

  # Enums for account types (matching Up Bank API)
  enum :account_type, {
    transactional: "TRANSACTIONAL",
    saver: "SAVER",
    home_loan: "HOME_LOAN"
  }, prefix: true

  # Calculate the projected balance at the end of a given month
  # @param date [Date] The date within the month to calculate for
  # @return [Float] The projected balance at the end of the month
  def end_of_month_balance(date = Date.today)
    normalized_date = normalized_projection_date(date)
    today = Date.today
    month_end = normalized_date.end_of_month

    if month_end < today
      # For past months: current balance minus all transactions from after month_end up to today
      # To get the balance at end of past month, we reverse all transactions that happened after
      # Using exclusive start (> month_end) and inclusive end (<= today) to match calendar_controller pattern
      transactions_after_month = transactions.where("transaction_date > ? AND transaction_date <= ?", month_end, today)
      sum_after = transactions_after_month.sum(:amount) || BigDecimal("0")
      current_balance - sum_after
    else
      # For current/future months: current balance plus all FUTURE transactions (after today)
      transactions_until_month_end = transactions
                                      .where(transaction_date: (today + 1.day)..month_end)
      future_sum = transactions_until_month_end.sum(:amount) || BigDecimal("0")
      current_balance + future_sum
    end
  end

  def target_savings_rate=(value)
    normalized_value = normalized_rate(value)
    super(normalized_value)
  end

  def target_savings_amount=(value)
    normalized_value = normalize_amount(value)
    super(normalized_value)
  end

  private

  def normalized_rate(value)
    decimal = cast_to_decimal(value)
    return MIN_TARGET_SAVINGS_RATE unless decimal

    decimal = decimal.clamp(MIN_TARGET_SAVINGS_RATE, MAX_TARGET_SAVINGS_RATE)
    decimal.truncate(4)
  end

  def normalize_amount(value)
    decimal = cast_to_decimal(value)
    return nil if decimal.nil?

    decimal = [ decimal, BigDecimal("0") ].max
    decimal.truncate(2)
  end

  def cast_to_decimal(value)
    return nil if value.nil? || (value.respond_to?(:empty?) && value.empty?)

    BigDecimal(value.to_s)
  rescue ArgumentError
    nil
  end

  def goal_fields_changed?
    will_save_change_to_target_savings_rate? || will_save_change_to_target_savings_amount?
  end

  def goal_timestamp_update_required?
    persisted? && goal_fields_changed?
  end

  def update_goal_timestamp
    self.goal_last_set_at = Time.current
  end

  def normalized_projection_date(date)
    candidate = date || Date.today

    if candidate.respond_to?(:to_date)
      candidate.to_date
    else
      Date.parse(candidate.to_s)
    end
  rescue ArgumentError, TypeError
    raise ArgumentError, "end_of_month_balance expects a Date-compatible argument"
  end
end
