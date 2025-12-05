FactoryBot.define do
  factory :project_member do
    association :project
    association :user
    role { "member" }
    can_create { true }
    can_edit { true }
    can_delete { false }
  end
end

