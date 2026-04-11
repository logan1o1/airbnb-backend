module JwtHelper
  extend self

  def current_jwt_token
    auth = request.headers["Authorization"].to_s
    scheme, token = auth.split(" ")
    scheme&.downcase == "bearer" ? token : nil
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
