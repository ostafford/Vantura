class ExpenseContribution < ApplicationRecord
  belongs_to :project_expense
  belongs_to :user
  belongs_to :paid_via_transaction, class_name: "Transaction", optional: true

  # Money Rails
  monetize :amount_cents, with_currency: :aud

  # Enums
  enum :status, {
    pending: "pending",
    paid: "paid"
  }

  validates :amount_cents, presence: true

  # Methods
  def paid?
    paid_at.present? || status == "paid"
  end

  def mark_as_paid!(transaction = nil)
    update!(
      paid_at: Time.current,
      paid_via_transaction: transaction
    )
  end
end
