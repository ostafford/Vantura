# frozen_string_literal: true

class ProjectPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    record.member?(user)
  end

  def create?
    user.present?
  end

  def update?
    record.can_edit?(user)
  end

  def destroy?
    record.can_delete?(user)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # Users can see projects they own or are members of
      owned_ids = user.owned_projects.pluck(:id)
      member_ids = user.projects.pluck(:id)
      scope.where(id: (owned_ids + member_ids).uniq)
    end
  end
end

