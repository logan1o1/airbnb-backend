class BookingsController < ApplicationController
  before_action :set_booking, only: [ :show, :cancel_booking ]
  before_action :authorize_booking_owner, only: [ :show, :cancel_booking  ]

  def index
    bookings = Rails.cache.fetch("bookings_index_#{current_user.id}", expires_in: 10.minutes) do
      Rails.logger.info("It was not a cache hit in bookings index")
      current_user.bookings
    end

    render json: {
      success: true,
      data: bookings
    }
  end

  def show
    render json: {
      success: true,
      data: booking_json(@booking)
    }
  end

  def create
    booked_listing = params.require(:booked_listing)
    from = params.require(:from)
    to = params.require(:to)

    booking = create_booking_atomically(booked_listing, from, to)

    render json: {
      success: true,
      data: {
        booking: booking_json(booking)
      },
      message: "Booking created successfully. Use the booking ID to initiate payment."
    }, status: :created
  rescue => e
    handle_booking_error(e)
  end

  def cancel_booking
    unless @booking.status.in?([ "pending", "failed" ])
      return render json: {
        success: false,
        error: "Cannot cancel a confirmed booking"
      }, status: :unprocessable_entity
    end

    @booking.update!(status: "cancelled")

    render json: {
      success: true,
      data: booking_json(@booking),
      message: "Booking cancelled successfully"
    }
  end

  private

  def create_booking_atomically(booked_listing, from, to)
    ActiveRecord::Base.transaction(isolation: :serializable) do
      _listing = Listing.lock.find(booked_listing)

      booking = current_user.bookings.build(
        booked_listing: booked_listing,
        from: from,
        to: to
      )
      booking.status = "pending"
      booking.save!

      booking
    end
  end

  def handle_booking_error(error)
    case error
    when ActiveRecord::RecordNotUnique
      raise ApiError.new("These dates are no longer available. Another booking was just confirmed for this period.", status: :conflict)
    when ActiveRecord::SerializationFailure
      raise ApiError.new("Booking temporarily unavailable. Please try again.", status: :service_unavailable)
    else
      raise ApiError.new(error.message, status: :unprocessable_entity)
    end
  end

  def set_booking
    booking_id = params.require(:id)
    @booking = Rails.cache.fetch("bookings_show_#{booking_id}", expires_in: 30.minutes) do
      Booking.find_by!(id: booking_id)
    end
  end

  def authorize_booking_owner
    raise ApiError.new("Unauthorized", status: :forbidden) unless @booking.user_id == current_user.id
  end

  def booking_params
    params.require(:booking).permit(:booked_listing, :from, :to)
  end

  def booking_json(booking)
    {
      id: booking.id,
      booked_listing: booking.booked_listing,
      user_id: booking.user_id,
      from: booking.from,
      to: booking.to,
      status: booking.status,
      created_at: booking.created_at
    }
  end
end
