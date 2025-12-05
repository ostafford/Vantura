FactoryBot.define do
  factory :filter do
    association :user
    name { Faker::Lorem.words(number: 2).join(" ") }
    filter_params { {} }
    filter_types { {} }
    date_range { {} }

    trait :with_category_filter do
      filter_params { { "category_id" => create(:category).id } }
    end

    trait :with_date_range do
      date_range do
        {
          "start_date" => 30.days.ago.to_date.to_s,
          "end_date" => Date.today.to_s
        }
      end
    end

    trait :with_transaction_type_filter do
      filter_params { { "transaction_type" => "expense" } }
    end

    trait :with_amount_range do
      filter_params do
        {
          "min_amount" => 10.0,
          "max_amount" => 100.0
        }
      end
    end

    trait :with_search do
      filter_params { { "search" => "coffee" } }
    end
  end
end

