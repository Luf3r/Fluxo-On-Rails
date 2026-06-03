# frozen_string_literal: true

module Transfers
  class Update
    class MissingPairError < StandardError; end

    def call(transaction:, from_account:, to_account:, amount:, date:, description: nil, status: nil)
      raise MissingPairError unless transaction.transfer? && transaction.transfer_pair
      raise Create::UnauthorizedTransferError unless from_account.user_id == to_account.user_id
      raise Create::SameAccountTransferError if from_account.id == to_account.id

      debit, credit = transfer_sides(transaction)

      ActiveRecord::Base.transaction do
        debit.update!(
          account: from_account,
          amount: amount,
          date: date,
          description: description,
          status: status.presence || debit.status,
          transaction_type: "transfer",
          transfer_direction: "outgoing",
          transfer_pair: credit
        )
        credit.update!(
          account: to_account,
          amount: amount,
          date: date,
          description: description,
          status: status.presence || credit.status,
          transaction_type: "transfer",
          transfer_direction: "incoming",
          transfer_pair: debit
        )

        [ debit, credit ]
      end
    end

    private

    def transfer_sides(transaction)
      pair = transaction.transfer_pair
      return [ pair, transaction ] if transaction.transfer_direction == "incoming"

      [ transaction, pair ]
    end
  end
end
