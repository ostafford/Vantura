class ProjectExpense < ApplicationRecord
  belongs_to :project
  belongs_to :paid_by_user, class_name: "User", optional: true
  # Uses 'transaction_record' instead of 'transaction' to avoid conflict with
  # ActiveRecord's transaction method (used for database transactions)
  # Reference: https://guides.rubyonrails.org/active_record_basics.html
  belongs_to :transaction_record, class_name: "Transaction", foreign_key: "transaction_id", optional: true
  belongs_to :category, optional: true
  has_many :expense_contributions, dependent: :destroy
  accepts_nested_attributes_for :expense_contributions, allow_destroy: true

  # Money Rails
  monetize :total_amount_cents, with_currency: :aud

  validates :description, presence: true
  validates :total_amount_cents, presence: true
  validates :expense_date, presence: true

  # Methods
  def split_evenly_among_members
    members = (project.members + [ project.owner ]).uniq
    amount_per_person = total_amount_cents / members.count

    members.each do |member|
      expense_contributions.create!(
        user: member,
        amount_cents: amount_per_person,
        amount_currency: total_amount_currency
      )
    end
  end

  def total_contributions_cents
    expense_contributions.sum(:amount_cents)
  end

  def is_fully_allocated?
    total_contributions_cents == total_amount_cents
  end
end
