# frozen_string_literal: true

class CreateCategoriesTagsAndTransactionTags < ActiveRecord::Migration[8.1]
  def change
    create_table :categories, id: :uuid, default: nil do |t|
      t.references :user, type: :uuid, foreign_key: true
      t.references :parent, type: :uuid, foreign_key: { to_table: :categories }
      t.string :name, null: false
      t.string :category_type, null: false, default: "expense"
      t.decimal :budget_amount, precision: 14, scale: 2
      t.boolean :system, null: false, default: false

      t.timestamps
    end

    add_index :categories, [ :user_id, :name ], unique: true
    add_index :categories, [ :system, :name ]
    add_check_constraint :categories, "category_type IN ('expense', 'income', 'both')",
      name: "chk_categories_category_type"
    add_check_constraint :categories, "budget_amount IS NULL OR budget_amount >= 0",
      name: "chk_categories_budget_amount_non_negative"
    add_check_constraint :categories, "system = FALSE OR user_id IS NULL",
      name: "chk_categories_system_user_ownership"
    add_check_constraint :categories, "parent_id IS NULL OR parent_id <> id",
      name: "chk_categories_parent_not_self"

    add_reference :transactions, :category, type: :uuid, foreign_key: true
    add_index :transactions, [ :category_id, :date ]

    create_table :tags, id: :uuid, default: nil do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :tags, [ :user_id, :name ], unique: true

    create_table :transaction_tags, id: :uuid, default: nil do |t|
      t.references :transaction, null: false, type: :uuid, foreign_key: true
      t.references :tag, null: false, type: :uuid, foreign_key: true

      t.timestamps
    end

    add_index :transaction_tags, [ :transaction_id, :tag_id ], unique: true
  end
end
