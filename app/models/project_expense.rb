class ProjectExpense < ApplicationRecord
  belongs_to :project
  belongs_to :transaction, optional: true
  belongs_to :category, optional: true
  has_many :expense_contributions, dependent: :destroy

  # Money Rails
  monetize :total_amount_cents, with_currency: :aud

  validates :description, presence: true
  validates :total_amount_cents, presence: true
  validates :expense_date, presence: true
end
