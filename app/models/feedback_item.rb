class FeedbackItem < ApplicationRecord
  belongs_to :user

  # Enums
  enum :feedback_type, {
    feature: "feature",
    bug: "bug",
    other: "other"
  }

  enum :status, {
    new: "new",
    in_progress: "in_progress",
    completed: "completed",
    rejected: "rejected"
  }

  # Validations
  validates :feedback_type, presence: true
  validates :description, presence: true

  # Scopes
  scope :unresolved, -> { where(status: [ "new", "in_progress" ]) }
  scope :resolved, -> { where(status: [ "completed", "rejected" ]) }
end
