# frozen_string_literal: true

module Transfers
  class Create
    class UnauthorizedTransferError < StandardError; end
    class SameAccountTransferError < StandardError; end

    class TransactionExecutor
      def save!(transaction)
        transaction.save!
      end
    end

    def initialize(transaction_executor: TransactionExecutor.new)
      @transaction_executor = transaction_executor
    end

    def call(from_account:, to_account:, amount:, date:, description: nil, status: nil)
      raise UnauthorizedTransferError unless from_account.user_id == to_account.user_id
      raise SameAccountTransferError if from_account.id == to_account.id

      ActiveRecord::Base.transaction do
        debit = build_transfer(
          account: from_account,
          amount: amount,
          date: date,
          description: description,
          status: status,
          transfer_direction: "outgoing"
        )
        credit = build_transfer(
          account: to_account,
          amount: amount,
          date: date,
          description: description,
          status: status,
          transfer_direction: "incoming"
        )

        @transaction_executor.save!(debit)
        credit.transfer_pair = debit
        @transaction_executor.save!(credit)
        debit.update!(transfer_pair: credit)

        [ debit, credit ]
      end
    end

    private

    def build_transfer(account:, amount:, date:, description:, status:, transfer_direction:)
      account.transactions.build(
        amount: amount,
        date: date,
        description: description,
        status: status,
        transaction_type: "transfer",
        transfer_direction: transfer_direction
      )
    end
  end
end
