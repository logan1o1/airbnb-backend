class Booking < ApplicationRecord
  belongs_to :listing, foreign_key: :booked_listing, inverse_of: :bookings
  belongs_to :user
  has_one :payment, foreign_key: :booking_id, inverse_of: :booking, dependent: :destroy

  validates :from, :to, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending confirmed failed] }
  validate :to_after_from

  enum :status, { pending: 'pending', confirmed: 'confirmed', failed: 'failed' }, prefix: true

  scope :confirmed, -> { where(status: 'confirmed') }
  scope :pending, -> { where(status: 'pending') }

  def overlaps_with_confirmed_bookings?
    Booking.confirmed
           .where(booked_listing: booked_listing)
           .where('tsrange("from", "to", \'[)\') && tsrange(?, ?, \'[)\')', from, to)
           .exists?
  end

  private

  def to_after_from
    return if from.blank? || to.blank?

    errors.add(:to, "to date must be after from date") if to <= from
  end
end
