# frozen_string_literal: true

class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts, id: :uuid, default: nil do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.string :name, null: false
      t.string :account_type, null: false, default: "checking"
      t.string :currency, null: false, default: "BRL"
      t.decimal :initial_balance, null: false, default: "0.0", precision: 14, scale: 2

      t.timestamps
    end

    add_index :accounts, [ :user_id, :name ]
    add_index :accounts, [ :user_id, :account_type ]
  end
end
