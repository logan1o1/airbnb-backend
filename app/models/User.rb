class User < ApplicationRecord
    has_many :owned_listings, class_name: "Listing", foreign_key: :owner_id, inverse_of: :owner, dependent: :restrict_with_exception
    has_many :bookings, dependent: :restrict_with_exception

    validates :first_name, :last_name, :email, :username, presence: true
    validates :email, :username, uniqueness: { case_sensitive: false }
    validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
end
