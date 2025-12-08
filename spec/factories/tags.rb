FactoryBot.define do
  factory :tag do
    sequence(:name) { |n| "#{Faker::Lorem.word.capitalize}_#{n}" }
  end
end
