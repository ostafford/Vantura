FactoryBot.define do
  factory :account do
    association :user
    up_id { "up-account-#{SecureRandom.hex(8)}" }
    account_type { "TRANSACTIONAL" }
    display_name { "Transaction Account" }
    balance_cents { 100000 }
    balance_currency { "AUD" }
  end
end
