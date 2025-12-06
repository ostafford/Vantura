FactoryBot.define do
  factory :notification do
    association :user
    notification_type { :transaction_created }
    title { Faker::Lorem.sentence(word_count: 3) }
    message { Faker::Lorem.paragraph }
    is_active { true }

    trait :read do
      read_at { Time.current }
    end

    trait :unread do
      read_at { nil }
    end

    trait :inactive do
      is_active { false }
    end

    trait :large_transaction do
      notification_type { :large_transaction }
      title { "Large Transaction Alert" }
      message { "A large transaction was detected" }
    end

    trait :sync_completed do
      notification_type { :sync_completed }
      title { "Sync Completed" }
      message { "Successfully synced transactions" }
    end

    trait :sync_failed do
      notification_type { :sync_failed }
      title { "Sync Failed" }
      message { "Failed to sync transactions" }
    end

    trait :goal_progress do
      notification_type { :goal_progress }
      title { "Goal Progress" }
      message { "You're making progress on your goal" }
    end

    trait :project_expense_added do
      notification_type { :project_expense_added }
      title { "Project Expense Added" }
      message { "A new expense was added to your project" }
    end
  end
end
