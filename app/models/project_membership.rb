class ProjectMembership < ApplicationRecord
  belongs_to :project
  belongs_to :user

  validates :user_id, uniqueness: { scope: :project_id }
  validates :access_level, presence: true

  enum :access_level, { limited: 0, full: 1 }
end
