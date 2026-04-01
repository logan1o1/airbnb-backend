class BookingsController < ApplicationController
  before_action :set_booking, only: [:show]

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
    # Create booking and initiate payment
    result = create_booking_and_payment
    
    if result[:booking].persisted? && result[:payment].persisted?
      render json: {
        success: true,
        data: {
          booking: booking_json(result[:booking]),
          payment: payment_json(result[:payment]),
          razorpay_key: ENV['RAZORPAY_KEY_ID']
        },
        message: "Booking created. Complete payment to confirm."
      }, status: :created
    else
      render json: {
        success: false,
        errors: result[:booking].errors.full_messages + result[:payment].errors.full_messages
      }, status: :unprocessable_entity
    end
  rescue => e
    handle_booking_error(e)
  end

  private

  def create_booking_and_payment
    ActiveRecord::Base.transaction(isolation: :serializable) do
      # Lock listing to serialize concurrent attempts
      _listing = Listing.lock.find(booking_params[:booked_listing])
      
      # Create booking with 'pending' status
      booking = current_user.bookings.build(booking_params)
      booking.status = 'pending'
      booking.save!
      
      # Create payment record
      idempotency_key = params[:idempotency_key] || SecureRandom.uuid
      razorpay_order = create_razorpay_order(booking)
      
      payment = booking.create_payment!(
        amount: booking.listing.price,
        razorpay_order_id: razorpay_order['id'],
        idempotency_key: idempotency_key,
        status: 'pending'
      )
      
      { booking: booking, payment: payment }
    end
  end

  def create_razorpay_order(booking)
    Razorpay::Client.new(
      key_id: ENV['RAZORPAY_KEY_ID'],
      key_secret: ENV['RAZORPAY_KEY_SECRET']
    ).order.create(
      amount: booking.listing.price,
      currency: 'INR',
      receipt: booking.id.to_s,
      notes: {
        booking_id: booking.id,
        listing_name: booking.listing.name
      }
    )
  end

  def create_booking_atomically
    ActiveRecord::Base.transaction(isolation: :serializable) do
      # Lock listing to serialize concurrent attempts for this listing
      _listing = Listing.lock.find(booking_params[:booked_listing])
      
      # Build booking with confirmed status
      booking = current_user.bookings.build(booking_params)
      booking.status = 'confirmed'
      
      # Save - either succeeds or fails at DB constraint level
      booking.save!
      booking
    end
  end

  def handle_booking_error(error)
    case error
    when ActiveRecord::RecordNotUnique, PG::ExclusionViolation
      # Exclusion constraint violation: overlapping booking exists
      render json: {
        success: false,
        error: 'These dates are no longer available. Another booking was just confirmed for this period.'
      }, status: :conflict
    when ActiveRecord::SerializationFailure
      # Serialization conflict (rare, but can happen under extreme load)
      render json: {
        success: false,
        error: 'Booking temporarily unavailable. Please try again.'
      }, status: :service_unavailable
    else
      render json: {
        success: false,
        error: error.message
      }, status: :unprocessable_entity
    end
  end

  def set_booking
    @booking = Booking.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: 'Booking not found' }, status: :not_found
  end

  def authorize_booking_owner!
    return if @booking.user_id == current_user.id

    render json: { success: false, error: 'Unauthorized' }, status: :forbidden
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
