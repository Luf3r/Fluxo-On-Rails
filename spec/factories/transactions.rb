FactoryBot.define do
  factory :transaction do
    association :account
    sequence(:description) { |n| "Transaction #{n}" }
    amount { 50.00 }
    date { Date.current }
    transaction_type { "expense" }
    status { "settled" }

    trait :income do
      transaction_type { "income" }
    end

    trait :expense do
      transaction_type { "expense" }
    end

    trait :transfer do
      transaction_type { "transfer" }
      transfer_direction { "outgoing" }
    end

    trait :settled do
      status { "settled" }
    end

    trait :pending do
      status { "pending" }
    end
  end
end
