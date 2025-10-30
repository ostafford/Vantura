class ExpenseContribution < ApplicationRecord
  belongs_to :project_expense
  belongs_to :user

  validates :share_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
