# frozen_string_literal: true

class TransactionTag < ApplicationRecord
  belongs_to :taggable_transaction,
             class_name: "Transaction",
             foreign_key: :transaction_id,
             inverse_of: :transaction_tags
  belongs_to :tag

  validates :tag_id, uniqueness: { scope: :transaction_id }
  validate :tag_belongs_to_transaction_user

  private

  def tag_belongs_to_transaction_user
    return if tag.blank? || taggable_transaction&.account.blank?
    return if tag.user_id == taggable_transaction.account.user_id

    errors.add(:tag, :invalid)
  end
end
