class AddStatusAndExclusionToBookings < ActiveRecord::Migration[8.1]
  def up
    add_column :bookings, :status, :string, default: 'pending', null: false
    add_index :bookings, :status

    # Create trigger function to prevent overlapping bookings
    execute <<-SQL
      CREATE OR REPLACE FUNCTION check_booking_overlap()
      RETURNS TRIGGER AS $$
      BEGIN
        IF NEW.status = 'confirmed' THEN
          IF EXISTS (
            SELECT 1 FROM bookings
            WHERE id != NEW.id
            AND booked_listing = NEW.booked_listing
            AND status = 'confirmed'
            AND tsrange("from", "to", '[)') && tsrange(NEW."from", NEW."to", '[)')
          ) THEN
            RAISE EXCEPTION 'Booking overlap: dates already booked for this listing';
          END IF;
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    # Create trigger that calls the function
    execute <<-SQL
      DROP TRIGGER IF EXISTS check_overlap_trigger ON bookings;
      CREATE TRIGGER check_overlap_trigger
      BEFORE INSERT OR UPDATE ON bookings
      FOR EACH ROW
      EXECUTE FUNCTION check_booking_overlap();
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS check_overlap_trigger ON bookings;"
    execute "DROP FUNCTION IF EXISTS check_booking_overlap();"
    remove_index :bookings, :status
    remove_column :bookings, :status
  end
end
