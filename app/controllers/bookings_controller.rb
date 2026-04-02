class BookingsController < ApplicationController
  before_action :set_booking, only: [ :show ]

  def index
    bookings = current_user.bookings
    render json: {
      success: true,
      data: bookings.map { |booking| booking_json(booking) }
    }
  end

  def show
    authorize_booking_owner!
    render json: {
      success: true,
      data: booking_json(@booking)
    }
  end

  def create
    result = create_booking_and_payment

    render json: {
      success: true,
      data: {
        booking: booking_json(result[:booking]),
        payment: payment_json(result[:payment]),
        razorpay_key: ENV["RAZORPAY_KEY_ID"]
      },
      message: "Booking created. Complete payment to confirm."
    }, status: :created
  rescue => e
    handle_booking_error(e)
  end

  private

  def create_booking_and_payment
    booked_listing = params.require(:booked_listing)
    from = params.require(:from)
    to = params.require(:to)
    idempotency_key = params[:idempotency_key] || SecureRandom.uuid

    ActiveRecord::Base.transaction(isolation: :serializable) do
      _listing = Listing.lock.find(booked_listing)

      booking = current_user.bookings.build(booked_listing: booked_listing, from: from, to: to)
      booking.status = "pending"
      booking.save!

      razorpay_order = create_razorpay_order(booking)

      payment = Payment.create!(
        booking_id: booking.id,
        amount: booking.listing.price,
        razorpay_order_id: razorpay_order["id"],
        idempotency_key: idempotency_key,
        status: "pending"
      )

      { booking: booking, payment: payment }
    end
  end

  def create_razorpay_order(booking)
    Razorpay::Client.new(
      key_id: ENV["RAZORPAY_KEY_ID"],
      key_secret: ENV["RAZORPAY_KEY_SECRET"]
    ).order.create(
      amount: booking.listing.price,
      currency: "INR",
      receipt: booking.id.to_s,
      notes: {
        booking_id: booking.id,
        listing_name: booking.listing.name
      }
    )
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
    @booking = Booking.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    raise ApiError.new("Booking not found", status: :not_found)
  end

  def authorize_booking_owner!
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

  def payment_json(payment)
    {
      id: payment.id,
      booking_id: payment.booking_id,
      amount: payment.amount,
      razorpay_order_id: payment.razorpay_order_id,
      status: payment.status
    }
  end
end
