FactoryBot.define do
  factory :tag do
    name { Faker::Lorem.word.capitalize }
  end
end
