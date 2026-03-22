class Booking < ApplicationRecord
  belongs_to :listing, foreign_key: :booked_listing, inverse_of: :bookings
  belongs_to :user

  validates :from, :to, presence: true
end
