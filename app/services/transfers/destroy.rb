# frozen_string_literal: true

module Transfers
  class Destroy
    def call(transaction)
      ActiveRecord::Base.transaction do
        pair = transaction.transfer? ? transaction.transfer_pair : nil

        if pair
          Transaction.where(id: [ transaction.id, pair.id ]).update_all(
            transfer_pair_id: nil,
            updated_at: Time.current
          )
          pair.destroy!
        end

        transaction.destroy!
      end
    end
  end
end
