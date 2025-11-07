class Project < ApplicationRecord
  belongs_to :owner, class_name: "User"

  has_many :project_memberships, dependent: :destroy
  has_many :members, through: :project_memberships, source: :user

  has_many :project_expenses, dependent: :destroy

  validates :name, presence: true

  # Returns unique list of participants (owner + members) as an ActiveRecord relation
  def participants
    User
      .where(id: owner_id)
      .or(User.where(id: project_memberships.select(:user_id)))
      .distinct
  end
end
