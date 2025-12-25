class InvestmentGoal < ApplicationRecord
  belongs_to :user
  belongs_to :account, optional: true

  validates :name, presence: true
  validates :target_amount, presence: true, numericality: { greater_than: 0 }
  validates :current_amount, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }
end

