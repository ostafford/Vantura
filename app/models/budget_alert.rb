class BudgetAlert < ApplicationRecord
  belongs_to :user
  belongs_to :budget

  validates :spent, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :limit, presence: true, numericality: { greater_than: 0 }
  validates :percentage, presence: true, numericality: { in: 0..100 }

  scope :for_period, ->(period_start) {
    where('created_at >= ?', period_start)
  }

  scope :recent_for_budget, ->(budget_id) {
    where(budget_id: budget_id).order(created_at: :desc)
  }
end

