# frozen_string_literal: true

class AddProfileParityFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :avatar_url, :string
    add_column :users, :email_verified_at, :datetime

    change_column_default :users, :currency, from: nil, to: "BRL"
    change_column_null :users, :name, false, "Fluxo User"
    change_column_null :users, :currency, false, "BRL"
  end
end
