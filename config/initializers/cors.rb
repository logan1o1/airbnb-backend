Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'  # Vite's default port
    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: false
  end
end