FactoryBot.define do
  factory :transaction_tag do
    association :taggable_transaction, factory: :transaction
    association :tag
  end
end
