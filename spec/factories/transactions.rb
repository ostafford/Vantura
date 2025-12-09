FactoryBot.define do
  factory :transaction do
    association :user
    association :account
    up_id { "up-transaction-#{SecureRandom.hex(8)}" }
    status { "settled" }
    raw_text { Faker::Lorem.sentence }
    description { Faker::Commerce.product_name }
    amount_cents { -rand(1000..100000) }
    created_at_up { 1.day.ago }
    settled_at { 1.day.ago }
  end
end
