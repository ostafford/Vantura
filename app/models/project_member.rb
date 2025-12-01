class ProjectMember < ApplicationRecord
  belongs_to :project
  belongs_to :user

  enum role: {
    owner: "owner",
    admin: "admin",
    member: "member"
  }

  validates :project_id, uniqueness: { scope: :user_id }
end
