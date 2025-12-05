FactoryBot.define do
  factory :expense_contribution do
    association :project_expense
    association :user
    amount_cents { Faker::Number.between(from: 100, to: 10000) }
    amount_currency { "AUD" }
    status { "pending" }

    trait :paid do
      status { "paid" }
      paid_at { Time.current }
    end
  end
end

