Devise.setup do |config|
  # Use Active Record as ORM
  require "devise/orm/active_record"

  # Basic configuration
  config.mailer_sender = "please-change-me@example.com"
  config.case_insensitive_keys = [ :email ]
  config.strip_whitespace_keys = [ :email ]
  config.skip_session_storage = [ :http_auth ]
  config.stretches = Rails.env.test? ? 1 : 12
  config.reconfirmable = true
  config.expire_all_remember_me_on_sign_out = true
  config.password_length = 6..128
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/
  config.reset_password_within = 6.hours

  # API-only: no navigational formats (no HTML redirects)
  config.navigational_formats = []

  config.sign_out_via = :delete

  # JWT configuration
  config.jwt do |jwt|
    jwt.secret = ENV["SECRET_KEY_BASE"].presence || Rails.application.secret_key_base
    jwt.dispatch_requests = [
      [ "POST", %r{^/auth/login$} ]
    ]
    jwt.revocation_requests = [
      [ "POST", %r{^/auth/logout$} ]
    ]
    jwt.expiration_time = 1.day.to_i
  end

  # Use JWT as the default strategy for :user scope
  config.warden do |manager|
    manager.default_strategies(scope: :user).unshift :jwt
  end
end
