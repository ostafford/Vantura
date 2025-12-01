FactoryBot.define do
  factory :user do
    email_address { Faker::Internet.email }
    password { "password123" }
    password_confirmation { "password123" }
    
    trait :with_up_bank_token do
      up_bank_token { "test_token_#{SecureRandom.hex(16)}" }
    end
  end
end

