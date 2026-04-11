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

ActiveRecord::Schema[8.1].define(version: 2026_04_10_144545) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "bookings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "booked_listing"
    t.datetime "created_at", null: false
    t.datetime "from"
    t.string "status", default: "pending", null: false
    t.datetime "to"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["booked_listing"], name: "index_bookings_on_booked_listing"
    t.index ["status"], name: "index_bookings_on_status"
    t.index ["user_id"], name: "index_bookings_on_user_id"
  end

  create_table "jwt_denylists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "exp"
    t.string "jti"
    t.datetime "updated_at", null: false
    t.index ["exp"], name: "index_jwt_denylists_on_exp"
    t.index ["jti"], name: "index_jwt_denylists_on_jti"
  end

  create_table "listings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "amenties"
    t.datetime "created_at", null: false
    t.string "location"
    t.string "name"
    t.bigint "owner_id"
    t.jsonb "pictures"
    t.bigint "price"
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_listings_on_owner_id"
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "amount", null: false
    t.uuid "booking_id", null: false
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "idempotency_key", null: false
    t.string "razorpay_order_id"
    t.string "razorpay_payment_id"
    t.string "razorpay_signature"
    t.string "short_url"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_id"], name: "index_payments_on_booking_id"
    t.index ["idempotency_key"], name: "index_payments_on_idempotency_key", unique: true
    t.index ["razorpay_payment_id"], name: "index_payments_on_razorpay_payment_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "encrypted_password", default: "", null: false
    t.string "first_name", limit: 50
    t.string "last_name", limit: 50
    t.datetime "updated_at", null: false
    t.string "username"
  end

  add_foreign_key "bookings", "listings", column: "booked_listing", on_delete: :cascade
  add_foreign_key "bookings", "users", on_delete: :cascade
  add_foreign_key "listings", "users", column: "owner_id", on_delete: :cascade
  add_foreign_key "payments", "bookings"
end
