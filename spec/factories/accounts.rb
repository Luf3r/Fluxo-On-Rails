FactoryBot.define do
  factory :account do
    association :user
    sequence(:name) { |n| "Account #{n}" }
    account_type { "checking" }
    currency { "BRL" }
    initial_balance { 100.00 }

    trait :checking do
      account_type { "checking" }
    end

    trait :savings do
      account_type { "savings" }
    end

    trait :investment do
      account_type { "investment" }
    end

    trait :cash do
      account_type { "cash" }
    end
  end
end
