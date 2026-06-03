# frozen_string_literal: true

class CreateTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :transactions, id: :uuid, default: nil do |t|
      t.references :account, null: false, type: :uuid, foreign_key: true
      t.uuid :transfer_pair_id
      t.string :description
      t.decimal :amount, null: false, precision: 14, scale: 2
      t.date :date, null: false
      t.string :transaction_type, null: false, default: "expense"
      t.string :status, null: false, default: "settled"
      t.string :transfer_direction

      t.timestamps
    end

    add_index :transactions, :transfer_pair_id
    add_index :transactions, [ :account_id, :date ]
    add_index :transactions, [ :account_id, :transaction_type ]
    add_index :transactions, [ :account_id, :status ]
    add_index :transactions, [ :transaction_type, :status ]
    add_foreign_key :transactions, :transactions, column: :transfer_pair_id
  end
end
