class Goal < ApplicationRecord
  belongs_to :user

  # Enums
  enum :goal_type, {
    net_zero: "net_zero",
    save_percentage: "save_percentage",
    spend_limit: "spend_limit"
  }

  enum :period, {
    monthly: "monthly",
    pay_cycle: "pay_cycle"
  }

  # Validations
  validates :name, presence: true
  validates :goal_type, presence: true
  validates :period, presence: true
  validates :target_amount_cents, presence: true, numericality: { greater_than: 0 }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
end
