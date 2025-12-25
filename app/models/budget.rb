class Budget < ApplicationRecord
  belongs_to :user
  belongs_to :category, optional: true
  has_many :budget_alerts, dependent: :destroy

  validates :name, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :period, inclusion: { in: %w[monthly weekly yearly] }
  validates :alert_threshold, numericality: { in: 0..100 }

  scope :active, -> { where(active: true) }
  scope :for_period, ->(date) {
    case period
    when 'monthly'
      where('start_date <= ? AND end_date >= ?', date.end_of_month, date.beginning_of_month)
    when 'weekly'
      where('start_date <= ? AND end_date >= ?', date.end_of_week, date.beginning_of_week)
    when 'yearly'
      where('start_date <= ? AND end_date >= ?', date.end_of_year, date.beginning_of_year)
    end
  }

  def spent_amount(user, date = Date.current)
    return 0 unless category_id

    transactions = user.transactions
      .settled
      .by_category(category_id)
      .by_date_range(period_start(date), period_end(date))

    # Use SQL aggregation instead of loading all records into memory
    transactions.sum("ABS(amount)")
  end

  def spent_percentage(user, date = Date.current)
    return 0 if amount.zero?
    (spent_amount(user, date) / amount * 100).round(2)
  end

  def alert_threshold_reached?(user, date = Date.current)
    spent_percentage(user, date) >= alert_threshold
  end

  private

  def period_start(date)
    case period
    when 'monthly' then date.beginning_of_month
    when 'weekly' then date.beginning_of_week
    when 'yearly' then date.beginning_of_year
    end
  end

  def period_end(date)
    case period
    when 'monthly' then date.end_of_month
    when 'weekly' then date.end_of_week
    when 'yearly' then date.end_of_year
    end
  end
end

