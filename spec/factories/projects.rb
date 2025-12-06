FactoryBot.define do
  factory :project do
    association :owner, factory: :user
    name { Faker::Lorem.words(number: 2).join(" ") }
    description { Faker::Lorem.paragraph }
    color { Faker::Color.hex_color }
  end
end
