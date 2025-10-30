class ProjectExpense < ApplicationRecord
  belongs_to :project
  has_many :expense_contributions, dependent: :destroy

  validates :merchant, presence: true
  validates :total_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Helper to recompute equal split across participants
  def rebuild_contributions!
    participants = project.participants
    return if participants.empty?

    base_share = total_cents / participants.size
    remainder = total_cents % participants.size

    expense_contributions.destroy_all

    participants.each do |participant|
      share = base_share
      if participant.id == project.owner_id
        share += remainder
      end
      expense_contributions.create!(user: participant, share_cents: share, paid: false, paid_at: nil)
    end
  end
end
