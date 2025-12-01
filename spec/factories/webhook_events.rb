FactoryBot.define do
  factory :webhook_event do
    association :user
    event_type { "TRANSACTION_CREATED" }
    payload { {} }

    trait :processed do
      processed_at { Time.current }
    end

    trait :failed do
      processed_at { Time.current }
      error_message { "Test error" }
    end
  end
end
