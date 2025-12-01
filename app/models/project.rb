class Project < ApplicationRecord
  belongs_to :owner, class_name: "User"
  has_many :project_members, dependent: :destroy
  has_many :members, through: :project_members, source: :user
  has_many :project_expenses, dependent: :destroy

  validates :name, presence: true

  # Methods
  def member?(user)
    members.include?(user) || owner == user
  end

  def can_create?(user)
    return true if owner == user
    project_members.find_by(user: user)&.can_create? || false
  end

  def can_edit?(user)
    return true if owner == user
    project_members.find_by(user: user)&.can_edit? || false
  end

  def can_delete?(user)
    return true if owner == user
    project_members.find_by(user: user)&.can_delete? || false
  end
end
