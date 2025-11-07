class FinancialInsight < ApplicationRecord
  # Associations
  belongs_to :account

  # Validations
  INSIGHT_TYPES = %w[spending_velocity savings_opportunity investment_suggestion category_merchant].freeze

  validates :insight_type, presence: true, inclusion: { in: INSIGHT_TYPES }
  validates :title, presence: true
  validates :message, presence: true

  # Scopes
  scope :actioned, -> { where(is_actioned: true) }
  scope :not_actioned, -> { where(is_actioned: false) }
  scope :by_type, ->(type) { where(insight_type: type) }
  scope :recent, -> { order(created_at: :desc) }

  # Serialize evidence_data as JSONB (Rails handles this automatically for jsonb columns)
  # No need for serialize - jsonb columns are automatically handled

  # Instance methods
  def actioned?
    is_actioned
  end

  def mark_as_actioned!
    update!(is_actioned: true)
  end
end
