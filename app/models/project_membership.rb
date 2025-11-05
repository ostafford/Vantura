class ProjectMembership < ApplicationRecord
  # Associations
  belongs_to :project
  belongs_to :user

  # Validations
  validates :user_id, uniqueness: { scope: :project_id }
  validates :access_level, presence: true

  # Enums
  enum :access_level, { limited: 0, full: 1 }
end
