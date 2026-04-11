class MakingForeignKeys < ActiveRecord::Migration[8.1]
  def up
    add_foreign_key :bookings, :users, column: :user_id, primary_key: :id, on_delete: :cascade
    add_foreign_key :bookings, :listings, column: :booked_listing, primary_key: :id, on_delete: :cascade
    add_foreign_key :listings, :users, column: :owner_id, primary_key: :id, on_delete: :cascade
  end

  def down
    remove_foreign_key :bookings, column: :user_id
    remove_foreign_key :bookings, column: :booked_listing
    remove_foreign_key :listings, column: :owner_id
  end
end
