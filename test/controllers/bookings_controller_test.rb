require "test_helper"

class BookingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      first_name: 'Test',
      last_name: 'User',
      username: 'testuser',
      email: 'test@example.com',
      password: 'Password123!',
      password_confirmation: 'Password123!'
    )
    @owner = User.create!(
      first_name: 'Owner',
      last_name: 'User',
      username: 'owner',
      email: 'owner@example.com',
      password: 'Password123!',
      password_confirmation: 'Password123!'
    )
    @listing = @owner.owned_listings.create!(
      name: 'Nice Place',
      location: 'NYC',
      price: 15000
    )
    @booking = @user.bookings.create!(
      booked_listing: @listing.id,
      from: 1.day.from_now,
      to: 5.days.from_now
    )
  end

  # INDEX tests
  test 'index returns 401 without auth' do
    get bookings_url, as: :json
    assert_response :unauthorized
  end

  test 'index returns 200 with auth and user bookings only' do
    get bookings_url, headers: auth_headers(@user), as: :json
    assert_response :success
    assert_equal 1, response.parsed_body['data'].length
  end

  # SHOW tests
  test 'show returns 401 without auth' do
    get booking_url(@booking), as: :json
    assert_response :unauthorized
  end

  test 'show returns 200 with auth and booking data' do
    get booking_url(@booking), headers: auth_headers(@user), as: :json
    assert_response :success
    assert_equal @booking.id, response.parsed_body['data']['id']
  end

  # CREATE tests
  test 'create returns 401 without auth' do
    post bookings_url,
         params: { booking: { booked_listing: @listing.id, from: 1.day.from_now, to: 3.days.from_now } },
         as: :json
    assert_response :unauthorized
  end

  test 'create returns 201 with auth and creates booking with user_id' do
    post bookings_url,
         params: { booking: { booked_listing: @listing.id, from: 10.days.from_now, to: 15.days.from_now } },
         headers: auth_headers(@user),
         as: :json
    assert_response :created
    assert_equal @user.id, response.parsed_body['data']['user_id']
  end

  private

  def auth_headers(user)
    post auth_login_url, params: { email: user.email, password: 'Password123!' }, as: :json
    token = response.parsed_body['token']
    { 'Authorization' => "Bearer #{token}" }
  end
end
