FactoryBot.define do
  factory :session do
    association :user
    ip_address { Faker::Internet.ip_v4_address }
    user_agent { Faker::Internet.user_agent }
    last_active_at { Time.current }

    trait :active do
      last_active_at { 1.hour.ago }
    end

    trait :expired do
      last_active_at { 3.hours.ago }
    end

    trait :new_session do
      last_active_at { nil }
    end
  end
end

