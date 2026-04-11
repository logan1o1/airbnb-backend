class Rack::Attack
  # Helper to extract user ID from JWT token in Authorization header
  def self.user_id_from_token(req)
    auth_header = req.env["HTTP_AUTHORIZATION"]
    return nil unless auth_header

    token = auth_header.split(" ").last
    return nil unless token

    begin
      payload = JWT.decode(token, Rails.application.credentials.devise_jwt_secret_key, true, algorithm: "HS256").first
      payload["sub"].to_i if payload["sub"]
    rescue
      nil
    end
  end

  # Allow all localhost requests during development
  safelist("mark dev requests safe") do |req|
    req.host == "localhost" || req.host == "127.0.0.1"
  end

  # Whitelist webhook endpoint from rate limiting
  # Razorpay webhooks should not be throttled
  safelist("allow razorpay webhooks") do |req|
    req.path == "/webhooks/razorpay"
  end

  # Whitelist login endpoint from user-based rate limiting
  # IP-based rate limiting still applies
  safelist("allow public login") do |req|
    req.path == "/auth/login" && req.post?
  end

  # Rate limit per IP: 100 requests per minute for general endpoints
  throttle("req/ip", limit: 100, period: 60) do |req|
    req.ip unless req.path.start_with?("/webhooks/")
  end

  # Rate limit bookings endpoint per authenticated user: 10 requests per hour
  throttle("bookings/user", limit: 10, period: 3600) do |req|
    if req.path == "/bookings" && req.post?
      user_id = user_id_from_token(req)
      "bookings:#{user_id}" if user_id
    end
  end

  # Rate limit payments endpoint per authenticated user: 5 requests per minute
  throttle("payments/user", limit: 5, period: 60) do |req|
    if req.path == "/payments" && req.post?
      user_id = user_id_from_token(req)
      "payments:#{user_id}" if user_id
    end
  end

  self.throttled_responder = lambda do |env|
    retry_after = (env["RateLimit-Reset"] || Time.now.to_i + 60).to_s
    [
      429,
      { "Content-Type" => "application/json", "Retry-After" => retry_after },
      [ { error: "Too many requests. Please try again later." }.to_json ]
    ]
  end
end

Rack::Attack.enabled = true
