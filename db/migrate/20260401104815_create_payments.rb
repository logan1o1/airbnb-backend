class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments do |t|
      t.uuid :booking_id, null: false
      t.bigint :amount, null: false # in paise (for Razorpay)
      t.string :razorpay_order_id
      t.string :razorpay_payment_id
      t.string :razorpay_signature
      t.string :status, default: 'pending', null: false # pending, authorized, captured, failed, refunded
      t.string :idempotency_key, null: false # for idempotency
      t.text :error_message

      t.timestamps
    end

    # Indexes for fast lookups
    add_index :payments, :booking_id
    add_index :payments, :razorpay_payment_id
    add_index :payments, :idempotency_key, unique: true

    # Foreign key to bookings
    add_foreign_key :payments, :bookings, column: :booking_id, primary_key: :id
  end
end
