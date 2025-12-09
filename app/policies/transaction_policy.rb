# frozen_string_literal: true

class TransactionPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    record.user == user
  end

  def update?
    record.user == user
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user: user)
    end
  end
end

