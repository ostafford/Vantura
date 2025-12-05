FactoryBot.define do
  factory :planned_transaction do
    association :user
    description { Faker::Lorem.sentence }
    amount_cents { Faker::Number.between(from: 1000, to: 100000) }
    amount_currency { "AUD" }
    planned_date { Date.current + 7.days }
    transaction_type { "expense" }

    trait :income do
      transaction_type { "income" }
    end

    trait :recurring do
      is_recurring { true }
      recurrence_pattern { "monthly" }
      recurrence_rule { "FREQ=MONTHLY" }
    end

    trait :linked do
      association :transaction_record, factory: :transaction
    end
  end
end

