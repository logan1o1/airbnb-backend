class PaymentsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :verify, :create ]
  before_action :set_booking, only: [ :create ]

  def create
    idempotency_key = params.require(:idempotency_key)
    phone = params.require(:phone)

    existing_payment = Payment.find_by(idempotency_key: idempotency_key)
    return render json: {
      success: true,
      data: payment_json(existing_payment),
      message: "Using existing payment (idempotent)"
    } if existing_payment

    existing_booking_payment = @booking.payment
    return render json: {
      success: true,
      data: payment_json(existing_booking_payment),
      message: "Payment already exists for this booking"
    } if existing_booking_payment

    payment = create_payment_atomically(idempotency_key, phone)
    payment.save!

    render json: {
      success: true,
      data: payment_json(payment)
    }, status: :created
  rescue ActionController::ParameterMissing => e
    raise ApiError.new("#{e.param.first} is required", status: :bad_request)
  rescue => e
    handle_payment_error(e)
  end

  def verify
    webhook_body = request.body.read
    webhook_signature = request.headers["X-Razorpay-Signature"]

    unless verify_razorpay_signature(webhook_body, webhook_signature)
      return render json: { success: false, error: "Invalid signature" }, status: :unauthorized
    end

    payload = JSON.parse(webhook_body)
    event_type = payload["event"]
    event_data = payload["payload"]["payment"]["entity"]

    case event_type
    when "payment.authorized", "payment.captured"
      handle_payment_captured(event_data)
    when "payment.failed"
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

  def create_payment_atomically(idempotency_key, phone)
    ActiveRecord::Base.transaction(isolation: :serializable) do
      begin
        Razorpay.headers = { "Content-type" => "application/json" }

        para_attr = {
          amount: @booking.listing.price * 100,
          currency: "INR",
          description: "Booking for #{@booking.listing.name}",
          customer: {
            name: current_user.first_name || current_user.username,
            email: current_user.email,
            contact: "+91#{phone}"
          },
          callback_url: "#{ENV['FRONTEND_URL']}/payment-success?booking_id=#{@booking.id}",
          callback_method: "get"
        }.to_json

        payment_link = Razorpay::PaymentLink.create(para_attr)

        payment = @booking.create_payment!(
          amount: @booking.listing.price,
          razorpay_order_id: payment_link.id,
          idempotency_key: idempotency_key,
          status: "pending"
        )

        payment.update!(short_url: payment_link.short_url)

        payment
      rescue Razorpay::Error => e
        Rails.logger.error("Razorpay Error: #{e.class} - #{e.message}")
        raise ApiError.new("Payment service error: #{e.message}", status: :service_unavailable)
      rescue => e
        Rails.logger.error("Payment Error: #{e.class} - #{e.message}")
        raise ApiError.new("Failed to create payment: #{e.message}", status: :unprocessable_entity)
      end
    end
  end

  def handle_payment_captured(event_data)
    razorpay_payment_id = event_data["id"]
    razorpay_order_id = event_data["order_id"]

    payment = Payment.find_by(razorpay_order_id: razorpay_order_id)
    return unless payment

    ActiveRecord::Base.transaction do
      payment.update!(
        status: "captured",
        razorpay_payment_id: razorpay_payment_id
      )

      payment.booking.update!(status: "confirmed")
    end
  end

  def handle_payment_failed(event_data)
    razorpay_order_id = event_data["order_id"]
    error_message = event_data["error_description"]

    payment = Payment.find_by(razorpay_order_id: razorpay_order_id)
    return unless payment

    ActiveRecord::Base.transaction do
      payment.update!(
        status: "failed",
        error_message: error_message
      )

      payment.booking.update!(status: "failed")
    end
  end

  def verify_razorpay_signature(body, signature)
    expected_signature = OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new("sha256"),
      ENV["RAZORPAY_KEY_SECRET"],
      body
    )

    ActiveSupport::SecurityUtils.secure_compare(expected_signature, signature)
  end

  def handle_payment_error(error)
    Rails.logger.error("Payment Error: #{error.class} - #{error.message}")
    case error
    when ActiveRecord::RecordNotUnique
      raise ApiError.new("Duplicate payment attempt", status: :conflict)
    when ActiveRecord::SerializationFailure
      raise ApiError.new("Payment temporarily unavailable. Please try again.", status: :service_unavailable)
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
      short_url: payment.short_url,
      created_at: payment.created_at
    }
  end
end
