# frozen_string_literal: true

require 'test_helper'

class ConcurrentBookingsTest < ActionDispatch::IntegrationTest
  setup do
    @user1 = User.create!(
      first_name: 'User1',
      last_name: 'Test',
      username: 'user1',
      email: 'user1@example.com',
      password: 'Password123!',
      password_confirmation: 'Password123!'
    )
    @user2 = User.create!(
      first_name: 'User2',
      last_name: 'Test',
      username: 'user2',
      email: 'user2@example.com',
      password: 'Password123!',
      password_confirmation: 'Password123!'
    )
    @owner = User.create!(
      first_name: 'Owner',
      last_name: 'Test',
      username: 'owner',
      email: 'owner@example.com',
      password: 'Password123!',
      password_confirmation: 'Password123!'
    )
    @listing = @owner.owned_listings.create!(
      name: 'Popular Apartment',
      location: 'NYC',
      price: 20000
    )
  end

  test 'concurrent bookings for same dates only allows one to succeed' do
    from_date = 5.days.from_now
    to_date = 10.days.from_now
    
    results = []
    threads = []

    # Spawn 2 threads that both try to book the same listing/dates
    2.times do |i|
      user = i == 0 ? @user1 : @user2
      thread = Thread.new do
        token = get_auth_token(user)
        response = post_booking(token, from_date, to_date)
        results << {
          user_id: user.id,
          status: response[:status],
          body: response[:body]
        }
      end
      threads << thread
    end

    # Wait for both threads to complete
    threads.each(&:join)

    # Verify: exactly one succeeded (201) and one failed (409 Conflict)
    successful = results.select { |r| r[:status] == 201 }
    conflict = results.select { |r| r[:status] == 409 }

    assert_equal 1, successful.length, "Expected exactly 1 successful booking, got #{successful.length}"
    assert_equal 1, conflict.length, "Expected exactly 1 conflict (409), got #{conflict.length}"

    # Verify: only one booking exists in DB for these dates
    confirmed_bookings = Booking.confirmed
                                .where(booked_listing: @listing.id)
    assert_equal 1, confirmed_bookings.count, "Expected 1 confirmed booking in DB"
    assert_equal 'confirmed', confirmed_bookings.first.status
  end

  test 'sequential bookings for different dates both succeed' do
    token1 = get_auth_token(@user1)
    token2 = get_auth_token(@user2)

    # User 1 books days 5-10
    response1 = post_booking(token1, 5.days.from_now, 10.days.from_now)
    assert_equal 201, response1[:status]

    # User 2 books days 15-20 (no overlap)
    response2 = post_booking(token2, 15.days.from_now, 20.days.from_now)
    assert_equal 201, response2[:status]

    # Both bookings should exist and be confirmed
    assert_equal 2, Booking.confirmed.count
  end

  test 'booking returns 409 conflict when dates overlap' do
    from_date = 5.days.from_now
    to_date = 10.days.from_now

    # User 1 books first
    token1 = get_auth_token(@user1)
    response1 = post_booking(token1, from_date, to_date)
    assert_equal 201, response1[:status]

    # User 2 tries to book overlapping dates
    token2 = get_auth_token(@user2)
    response2 = post_booking(token2, from_date, 12.days.from_now)
    assert_equal 409, response2[:status]
    assert_match(/no longer available/, response2[:body]['error'])
  end

  private

  def get_auth_token(user)
    post auth_login_url, params: { email: user.email, password: 'Password123!' }, as: :json
    response.parsed_body['token']
  end

  def post_booking(token, from_date, to_date)
    post bookings_url,
         params: {
           booking: {
             booked_listing: @listing.id,
             from: from_date,
             to: to_date
           }
         },
         headers: { 'Authorization' => "Bearer #{token}" },
         as: :json

    {
      status: response.status,
      body: response.parsed_body
    }
  end
end
