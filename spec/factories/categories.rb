FactoryBot.define do
  factory :category do
    association :user
    sequence(:name) { |n| "Category #{n}" }
    category_type { "expense" }
    budget_amount { nil }
    system { false }

    trait :income do
      category_type { "income" }
    end

    trait :both do
      category_type { "both" }
    end

    trait :system do
      user { nil }
      system { true }
      sequence(:name) { |n| "System category #{n}" }
      category_type { "both" }
    end
  end
end
