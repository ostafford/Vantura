FactoryBot.define do
  factory :project_expense do
    association :project
    description { Faker::Lorem.sentence }
    total_amount_cents { Faker::Number.between(from: 1000, to: 100000) }
    total_amount_currency { "AUD" }
    expense_date { Date.current }
    association :paid_by_user, factory: :user

    trait :with_category do
      association :category
    end

    trait :with_transaction do
      association :transaction_record, factory: :transaction
    end
  end
end
