# frozen_string_literal: true

class Account < ApplicationRecord
  ACCOUNT_TYPES = %w[checking savings investment cash].freeze
  MAX_INITIAL_BALANCE = BigDecimal("999999999999.99")

  belongs_to :user
  before_destroy :destroy_paired_transfer_transactions

  has_many :transactions, dependent: :destroy

  enum :account_type, ACCOUNT_TYPES.index_with(&:itself), validate: true

  before_validation :set_defaults

  validates :name, :currency, :initial_balance, presence: true
  validates :account_type, inclusion: { in: ACCOUNT_TYPES }
  validates :initial_balance, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: MAX_INITIAL_BALANCE
  }
  validates :currency, inclusion: { in: User::SUPPORTED_CURRENCIES }

  def current_balance
    settled_transactions = transactions.settled

    initial_balance +
      settled_transactions.income.sum(:amount) +
      settled_transactions.transfer_incoming.sum(:amount) -
      settled_transactions.expense.sum(:amount) -
      settled_transactions.transfer_outgoing.sum(:amount)
  end

  private

  def set_defaults
    self.account_type ||= "checking"
    self.currency ||= user&.currency || "BRL"
    self.initial_balance = 0 if initial_balance.nil?
  end

  def destroy_paired_transfer_transactions
    transactions.transfer.includes(:transfer_pair).find_each do |transaction|
      Transfers::Destroy.new.call(transaction)
    end
  end
end
