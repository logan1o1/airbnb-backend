class CreateBookings < ActiveRecord::Migration[8.1]
  def change
    create_table :bookings, id: :uuid do |t|
      t.uuid :booked_listing
      t.bigint :user_id
      t.datetime :from
      t.datetime :to
      t.timestamps
    end
  end
end
