# frozen_string_literal: true

class ListingsController < ApplicationController
  before_action :set_listing, only: [:show]

  def index
    listings = Listing.all
    render json: {
      success: true,
      data: listings.map { |listing| listing_json(listing) }
    }
  end

  def show
    render json: {
      success: true,
      data: listing_json(@listing)
    }
  end

  def create
    name = params.require(:name)
    location = params.require(:location)
    price = params.require(:price)
    pictures = params[:pictures]

    listing = current_user.owned_listings.build(name: name, location: location, price: price, pictures: pictures)
    listing.save!

    render json: {
      success: true,
      data: listing_json(listing)
    }, status: :created
  end

  private

  def set_listing
    @listing = Listing.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    raise ApiError.new("Listing not found", status: :not_found)
  end

  def listing_params
    params.require(:listing).permit(:name, :location, :price, :pictures)
  end

  def listing_json(listing)
    {
      id: listing.id,
      name: listing.name,
      location: listing.location,
      price: listing.price,
      pictures: listing.pictures,
      owner_id: listing.owner_id,
      created_at: listing.created_at
    }
  end
end
