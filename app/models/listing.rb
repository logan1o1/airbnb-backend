class Listing < ApplicationRecord
  belongs_to :owner, class_name: "User", inverse_of: :owned_listings
  has_many :bookings, foreign_key: :booked_listing, inverse_of: :listing, dependent: :destroy

  validates :name, :location, presence: true
  validates :price, presence: true, numericality: { only_integer: true, greater_than: 0 }
end
