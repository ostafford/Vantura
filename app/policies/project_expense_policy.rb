# frozen_string_literal: true

class ProjectExpensePolicy < ApplicationPolicy
  def index?
    record.project.member?(user)
  end

  def show?
    record.project.member?(user)
  end

  def create?
    record.project.member?(user)
  end

  def update?
    record.project.can_edit?(user)
  end

  def destroy?
    record.project.can_edit?(user)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # Users can see expenses for projects they're members of
      owned_project_ids = user.owned_projects.pluck(:id)
      member_project_ids = user.projects.pluck(:id)
      scope.where(project_id: (owned_project_ids + member_project_ids).uniq)
    end
  end
end

