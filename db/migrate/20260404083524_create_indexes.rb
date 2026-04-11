class CreateIndexes < ActiveRecord::Migration[8.1]
  def up
    add_index :listings, :owner_id
    add_index :bookings, :booked_listing
    add_index :bookings, :user_id
  end

  def down
    remove_index :bookings, :user_id
    remove_index :bookings, :booked_listing
    remove_index :listings, :owner_id
  end
end
