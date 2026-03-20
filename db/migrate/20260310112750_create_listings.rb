class CreateListings < ActiveRecord::Migration[8.1]
  def change
    create_table :listings, id: :uuid do |t|
      t.string :name
      t.bigint :owner_id
      t.jsonb :pictures
      t.bigint :price
      t.string :location
      t.timestamps
    end
  end
end
