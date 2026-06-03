# frozen_string_literal: true

class Tag < ApplicationRecord
  belongs_to :user
  has_many :transaction_tags, dependent: :destroy
  has_many :transactions, through: :transaction_tags, source: :taggable_transaction

  before_validation :normalize_name

  validates :name, presence: true
  validates :name, uniqueness: { scope: :user_id, case_sensitive: false }

  private

  def normalize_name
    self.name = name.to_s.strip.downcase
  end
end
