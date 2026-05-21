# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_20_190000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "User", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.text "avatarUrl"
    t.datetime "createdAt", precision: 3, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.text "currency", null: false
    t.text "email", null: false
    t.datetime "emailVerifiedAt", precision: 3
    t.text "name", null: false
    t.text "passwordHash", null: false
    t.datetime "updatedAt", precision: 3, null: false
    t.index ["email"], name: "User_email_key", unique: true
  end

  create_table "_prisma_migrations", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.integer "applied_steps_count", default: 0, null: false
    t.string "checksum", limit: 64, null: false
    t.timestamptz "finished_at"
    t.text "logs"
    t.string "migration_name", limit: 255, null: false
    t.timestamptz "rolled_back_at"
    t.timestamptz "started_at", default: -> { "now()" }, null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.string "currency", default: "BRL", null: false
    t.string "email", default: "", null: false
    t.datetime "email_verified_at"
    t.string "encrypted_password", default: "", null: false
    t.string "name", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end
end
