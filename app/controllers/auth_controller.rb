class AuthController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :login, :signup ]

  def signup
    username = params.require(:username)
    first_name = params.require(:first_name)
    last_name = params.require(:last_name)
    email = params.require(:email)
    password = params.require(:password)

    user = User.new(username: username, first_name: first_name, last_name: last_name, email: email, password: password)
    user.save!

    token, = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil)

    render json: {
      success: true,
      token: token,
      user: {
        id: user.id,
        email: user.email,
        username: user.username,
        first_name: user.first_name,
        last_name: user.last_name
      }
    }, status: :created
  end

  def login
    email = params.require(:email)
    password = params.require(:password)

    user = User.find_by(email: email)

    raise ApiError.new("Invalid email or password", status: :unauthorized) unless user&.valid_password?(password)

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
  end

  def logout
    auth_header = request.headers["Authorization"].to_s
    token = auth_header.split(" ").last if auth_header.present?

    payload = JwtHelper.decode_jwt_payload(token) if token.present?

    JwtHelper.revoke_token(payload) if payload.present?

    sign_out(current_user) if current_user

    render json: { success: true, message: "Logged out successfully" }
  end
end
