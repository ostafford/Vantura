class ProjectExpense < ApplicationRecord
  include Turbo::Broadcastable

  belongs_to :project
  has_many :expense_contributions, dependent: :destroy

  validates :merchant, presence: true
  validates :total_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Temporary storage for contributor IDs from controller params
  attr_accessor :contributor_user_ids

  # Callbacks
  after_save :rebuild_contributions_automatically
  after_create_commit :broadcast_projects_index_update
  after_destroy_commit :broadcast_projects_index_update

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

  # Helper to recompute equal split across selected participants only
  def rebuild_contributions_for_participants!(participant_ids)
    return if participant_ids.blank?

    # Convert to integers and filter to valid project participants
    selected_ids = Array(participant_ids).map(&:to_i).uniq
    all_participants = project.participants
    selected_participants = all_participants.select { |p| selected_ids.include?(p.id) }

    return if selected_participants.empty?

    base_share = total_cents / selected_participants.size
    remainder = total_cents % selected_participants.size

    expense_contributions.destroy_all

    selected_participants.each do |participant|
      share = base_share
      if participant.id == project.owner_id
        share += remainder
      end
      expense_contributions.create!(user: participant, share_cents: share, paid: false, paid_at: nil)
    end
  end

  private

  # Automatically rebuild contributions when expense is created or updated
  def rebuild_contributions_automatically
    # Use contributor_user_ids if provided, otherwise default to all participants
    contributor_ids = contributor_user_ids.presence || project.participants.pluck(:id)
    rebuild_contributions_for_participants!(contributor_ids)
  end

  # Broadcast projects index updates after expense changes
  def broadcast_projects_index_update
    ProjectExpenseBroadcastService.call(self)
  end
end
