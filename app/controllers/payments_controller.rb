class PaymentsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:verify]
  before_action :set_booking, only: [:create]

  def create
    idempotency_key = params[:idempotency_key] || SecureRandom.uuid
    
    # Check for duplicate (idempotency)
    existing_payment = Payment.find_by(idempotency_key: idempotency_key)
    return render json: {
      success: true,
      data: payment_json(existing_payment),
      message: 'Using existing payment (idempotent)'
    } if existing_payment

    # Create payment record
    payment = create_payment_atomically(idempotency_key)
    payment.save!

    render json: {
      success: true,
      data: payment_json(payment),
      razorpay_key: ENV['RAZORPAY_KEY_ID']
    }, status: :created
  rescue => e
    handle_payment_error(e)
  end

  def verify
    # Verify webhook signature from Razorpay
    webhook_body = request.body.read
    webhook_signature = request.headers['X-Razorpay-Signature']

    unless verify_razorpay_signature(webhook_body, webhook_signature)
      return render json: { success: false, error: 'Invalid signature' }, status: :unauthorized
    end

    payload = JSON.parse(webhook_body)
    event_type = payload['event']
    event_data = payload['payload']['payment']['entity']

    case event_type
    when 'payment.authorized', 'payment.captured'
      handle_payment_captured(event_data)
    when 'payment.failed'
      handle_payment_failed(event_data)
    end

    render json: { success: true }
  end

  private

  def set_booking
    @booking = Booking.find(params[:booking_id])
  rescue ActiveRecord::RecordNotFound
    raise ApiError.new("Booking not found", status: :not_found)
  end

  def create_payment_atomically(idempotency_key)
    ActiveRecord::Base.transaction(isolation: :serializable) do
      # Create Razorpay order
      razorpay_order = create_razorpay_order(@booking)
      
      # Create payment record
      payment = @booking.create_payment!(
        amount: @booking.listing.price,
        razorpay_order_id: razorpay_order['id'],
        idempotency_key: idempotency_key,
        status: 'pending'
      )

      payment
    end
  end

  def create_razorpay_order(booking)
    # Initialize Razorpay client
    Razorpay::Client.new(key_id: ENV['RAZORPAY_KEY_ID'], key_secret: ENV['RAZORPAY_KEY_SECRET'])
      .order.create(
        amount: booking.listing.price, # in paise
        currency: 'INR',
        receipt: booking.id.to_s,
        notes: {
          booking_id: booking.id,
          listing_name: booking.listing.name
        }
      )
  end

  def handle_payment_captured(event_data)
    razorpay_payment_id = event_data['id']
    razorpay_order_id = event_data['order_id']

    payment = Payment.find_by(razorpay_order_id: razorpay_order_id)
    return unless payment

    ActiveRecord::Base.transaction do
      # Update payment status
      payment.update!(
        status: 'captured',
        razorpay_payment_id: razorpay_payment_id
      )

      # Confirm booking
      payment.booking.update!(status: 'confirmed')
    end
  end

  def handle_payment_failed(event_data)
    razorpay_order_id = event_data['order_id']
    error_message = event_data['error_description']

    payment = Payment.find_by(razorpay_order_id: razorpay_order_id)
    return unless payment

    ActiveRecord::Base.transaction do
      # Update payment status
      payment.update!(
        status: 'failed',
        error_message: error_message
      )

      # Mark booking as failed
      payment.booking.update!(status: 'failed')
    end
  end

  def verify_razorpay_signature(body, signature)
    expected_signature = OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new('sha256'),
      ENV['RAZORPAY_KEY_SECRET'],
      body
    )

    ActiveSupport::SecurityUtils.secure_compare(expected_signature, signature)
  end

  def handle_payment_error(error)
    case error
    when ActiveRecord::RecordNotUnique
      raise ApiError.new("Duplicate payment attempt", status: :conflict)
    else
      raise ApiError.new(error.message, status: :unprocessable_entity)
    end
  end

  def payment_json(payment)
    {
      id: payment.id,
      booking_id: payment.booking_id,
      amount: payment.amount,
      razorpay_order_id: payment.razorpay_order_id,
      razorpay_payment_id: payment.razorpay_payment_id,
      status: payment.status,
      created_at: payment.created_at
    }
  end
end
