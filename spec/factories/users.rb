FactoryBot.define do
  factory :user do
    name { "Fluxo User" }
    currency { "BRL" }
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
  end
end
