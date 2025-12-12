class PlannedTransaction < ApplicationRecord
  belongs_to :user
  # Uses 'transaction_record' instead of 'transaction' to avoid conflict with
  # ActiveRecord's transaction method (used for database transactions)
  # Reference: https://guides.rubyonrails.org/active_record_basics.html
  belongs_to :transaction_record, class_name: "Transaction", foreign_key: "transaction_id", optional: true
  belongs_to :category, optional: true

  # Money Rails
  monetize :amount_cents, with_currency: :aud

  # Enums
  enum :transaction_type, {
    expense: "expense",
    income: "income"
  }

  # Validations
  validates :planned_date, presence: true
  validates :description, presence: true
  validates :amount_cents, presence: true

  # Scopes
  scope :upcoming, -> { where("planned_date >= ?", Date.current) }
  scope :past, -> { where("planned_date < ?", Date.current) }
  scope :by_date_range, ->(start_date, end_date) {
    where(planned_date: start_date..end_date)
  }

  # Methods
  def linked?
    transaction_record.present?
  end

  # Generate occurrences for a given month using ice_cube
  # Returns array of occurrence data hashes with date and transaction details
  def occurrences_for_month(year, month, max_occurrences: 100)
    start_of_month = Date.new(year, month, 1)
    end_of_month = start_of_month.end_of_month
    occurrences_for_date_range(start_of_month, end_of_month, max_occurrences: max_occurrences)
  end

  # Generate occurrences for a date range
  # Returns array of occurrence data hashes with date and transaction details
  def occurrences_for_date_range(start_date, end_date, max_occurrences: 100)
    # For non-recurring transactions, return single occurrence if in range
    unless is_recurring?
      return planned_date >= start_date && planned_date <= end_date ? [ occurrence_data(planned_date) ] : []
    end

    # Build ice_cube schedule
    schedule = build_ice_cube_schedule

    # Generate occurrences for the date range
    occurrences = schedule.occurrences(end_date).select do |date|
      date >= start_date && date <= end_date
    end

    # Limit to max_occurrences
    occurrences = occurrences.first(max_occurrences)

    # Convert to occurrence data hashes
    occurrences.map { |date| occurrence_data(date) }
  end

  # Build IceCube schedule for this planned transaction
  def build_ice_cube_schedule
    schedule = IceCube::Schedule.new(planned_date)

    # Parse recurrence pattern and build recurrence rule
    case recurrence_pattern&.downcase
    when "daily"
      schedule.add_recurrence_rule(IceCube::Rule.daily)
    when "weekly"
      schedule.add_recurrence_rule(IceCube::Rule.weekly)
    when "monthly"
      schedule.add_recurrence_rule(IceCube::Rule.monthly)
    when "yearly"
      schedule.add_recurrence_rule(IceCube::Rule.yearly)
    else
      # Try to parse recurrence_rule if provided (iCal format)
      if recurrence_rule.present?
        begin
          rule = IceCube::Rule.from_ical(recurrence_rule)
          schedule.add_recurrence_rule(rule) if rule
        rescue => e
          Rails.logger.error "Failed to parse recurrence_rule: #{e.message}"
          return schedule
        end
      else
        # Default to monthly if pattern not recognized
        schedule.add_recurrence_rule(IceCube::Rule.monthly)
      end
    end

    # Apply end date if present
    if recurrence_end_date.present?
      schedule.recurrence_rules.first.until(recurrence_end_date) if schedule.recurrence_rules.any?
    end

    schedule
  end

  private

  def occurrence_data(date)
    {
      date: date,
      planned_transaction: self,
      description: description,
      amount_cents: amount_cents,
      transaction_type: transaction_type,
      category: category
    }
  end
end
