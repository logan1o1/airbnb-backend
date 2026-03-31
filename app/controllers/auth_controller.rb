class AuthController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :login ]

  def login
    user = User.find_by(email: params[:email])

    if user&.valid_password?(params[:password])
      token, = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil)

      render json: {
        success: true,
        token: token,
        user: {
          id: user.id,
          email: user.email,
          username: user.username
        }
      }
    else
      render json: {
        success: false,
        error: "Invalid email or password"
      }, status: :unauthorized
    end
  end

  def logout
    token = current_jwt_token
    payload = decode_jwt_payload(token)

    revoke_token(payload) if payload.present?

    sign_out(current_user) if current_user

    render json: { success: true, message: "Logged out successfully" }
  end

  private

  def current_jwt_token
    request.env["warden-jwt_auth.token"] || request.headers["Authorization"]&.split(" ")&.last
  end

  def decode_jwt_payload(token)
    return if token.blank?

    Warden::JWTAuth::TokenDecoder.new.call(token)
  rescue JWT::ExpiredSignature, JWT::DecodeError
    nil
  end

  def revoke_token(payload)
    return if payload.blank?

    jti = payload["jti"]
    exp = payload["exp"]
    return if jti.blank?

    JwtDenylist.find_or_create_by!(jti: jti) do |denylist|
      denylist.exp = Time.zone.at(exp) if exp.present?
    end
  end
end
