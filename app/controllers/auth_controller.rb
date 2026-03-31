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
    token = JwtHelper.current_jwt_token
    payload = JwtHelper.decode_jwt_payload(token)

    JwtHelper.revoke_token(payload) if payload.present?

    sign_out(current_user) if current_user

    render json: { success: true, message: "Logged out successfully" }
  end
end
