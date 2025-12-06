FactoryBot.define do
  factory :recurring_transaction do
    association :account
    description { Faker::Commerce.product_name }
    amount { Faker::Commerce.price(range: 10.0..500.0) }
    frequency { "monthly" }
    next_occurrence_date { Date.current + 1.month }
    is_active { true }
    transaction_type { "expense" }
    amount_tolerance { 1.0 }
    projection_months { "indefinite" }

    trait :weekly do
      frequency { "weekly" }
      next_occurrence_date { Date.current + 1.week }
    end

    trait :daily do
      frequency { "daily" }
      next_occurrence_date { Date.current + 1.day }
    end

    trait :yearly do
      frequency { "yearly" }
      next_occurrence_date { Date.current + 1.year }
    end

    trait :income do
      transaction_type { "income" }
      amount { Faker::Commerce.price(range: 1000.0..5000.0) }
    end

    trait :with_template_transaction do
      association :template_transaction, factory: :transaction
    end

    trait :inactive do
      is_active { false }
    end

    trait :with_merchant_pattern do
      merchant_pattern { "NETFLIX|Netflix" }
    end

    trait :with_category do
      category { "Entertainment" }
    end
  end
end
