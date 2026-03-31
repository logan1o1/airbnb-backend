class Booking < ApplicationRecord
  belongs_to :listing, foreign_key: :booked_listing, inverse_of: :bookings
  belongs_to :user

  validates :from, :to, presence: true
  validate :to_after_from

  private

  def to_after_from
    return if from.blank? || to.blank?

    errors.add(:to, "to date must be after from date") if to <= from
  end
end
