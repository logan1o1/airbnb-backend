require "test_helper"

class ListingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(
      first_name: 'Owner',
      last_name: 'User',
      username: 'owner_user',
      email: 'owner@example.com',
      password: 'Password123!',
      password_confirmation: 'Password123!'
    )
    @listing = @owner.owned_listings.create!(
      name: 'Cozy Apartment',
      location: 'New York',
      price: 10000
    )
  end

  # INDEX tests
  test 'index returns 401 without auth' do
    get listings_url, as: :json
    assert_response :unauthorized
  end

  test 'index returns 200 with auth and includes created listing' do
    get listings_url, headers: auth_headers(@owner), as: :json
    assert_response :success
    listing_ids = response.parsed_body['data'].map { |l| l['id'] }
    assert listing_ids.include?(@listing.id.to_s)
  end

  # SHOW tests
  test 'show returns 401 without auth' do
    get listing_url(@listing), as: :json
    assert_response :unauthorized
  end

  test 'show returns 200 with auth and listing data' do
    get listing_url(@listing), headers: auth_headers(@owner), as: :json
    assert_response :success
    assert_equal @listing.id, response.parsed_body['data']['id']
  end

  # CREATE tests
  test 'create returns 401 without auth' do
    post listings_url, params: { listing: { name: 'Test', location: 'Test', price: 1000 } }, as: :json
    assert_response :unauthorized
  end

  test 'create returns 201 with auth and creates listing with owner_id' do
    post listings_url,
         params: { listing: { name: 'New Place', location: 'Boston', price: 8000 } },
         headers: auth_headers(@owner),
         as: :json
    assert_response :created
    assert_equal @owner.id, response.parsed_body['data']['owner_id']
  end

  private

  def auth_headers(user)
    post auth_login_url, params: { email: user.email, password: 'Password123!' }, as: :json
    token = response.parsed_body['token']
    { 'Authorization' => "Bearer #{token}" }
  end
end
