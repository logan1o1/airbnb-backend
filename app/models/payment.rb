class Payment < ApplicationRecord
  belongs_to :booking, foreign_key: :booking_id, inverse_of: :payment

  validates :amount, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :idempotency_key, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: %w[pending authorized captured failed refunded] }

  enum :status, { pending: 'pending', authorized: 'authorized', captured: 'captured', failed: 'failed', refunded: 'refunded' }, prefix: true

  scope :successful, -> { where(status: 'captured') }
  scope :failed, -> { where(status: 'failed') }
end
