class ApplicationController < ActionController::API
  include Devise::Controllers::Helpers

  before_action :authenticate_user!

  class ApiError < StandardError
    attr_reader :status, :details

    def initialize(message = "Bad request", status: :bad_request, details: nil)
      super(message)
      @status = status
      @details = details
    end
  end

  rescue_from ActiveRecord::RecordInvalid do |e|
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  rescue_from ActiveRecord::RecordNotFound do |e|
    render json: { success: false, error: e.message }, status: :not_found
  end

  rescue_from ActiveRecord::SoleRecordExceeded do |e|
    render json: { success: false, error: e.message }, status: :conflict
  end

  rescue_from ActiveRecord::RecordNotUnique do |e|
    render json: { success: false, error: e.message }, status: :conflict
  end

  rescue_from ActiveRecord::InvalidForeignKey do |e|
    render json: { success: false, error: e.message }, status: :conflict
  end

  rescue_from ActionController::ParameterMissing do |e|
    render json: { success: false, error: e.message }, status: :bad_request
  end

  rescue_from ActionController::RoutingError do |e|
    render json: { success: false, error: e.message }, status: :not_found
  end

  rescue_from ArgumentError do |e|
    render json: { success: false, error: e.message }, status: :bad_request
  end

  rescue_from JSON::ParserError do |e|
    render json: { success: false, error: e.message }, status: :bad_request
  end

  rescue_from ApplicationController::ApiError do |e|
    Rails.logger.warn "ApiError [#{e.status}]: #{e.message}"
    render json: { success: false, error: e.message, details: e.details }, status: e.status
  end
end
