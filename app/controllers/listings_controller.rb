class ListingsController < ApplicationController
  before_action :set_listing, only: [ :show, :update, :destroy ]
  before_action :authorize_listing, only: [ :update, :destroy ]

  def index
    listings = Listing.where.not(owner_id: current_user.id)
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

  def my_listings
    listings = Listing.where(owner_id: current_user.id)
    render json: {
      success: true,
      data: listings.map { |listing| listing_json(listing) }
    }
  end

  def update
    name = params.require(:name)
    location = params.require(:location)
    price = params.require(:price)
    pictures = params[:pictures]

    @listing.name = name
    @listing.location = location
    @listing.price = price

    if pictures.present?
      new_picture_urls = ImageUploader.upload_multiple_images(pictures)
      existing_pictures = @listing.pictures || []
      @listing.pictures = existing_pictures + new_picture_urls
    end

    @listing.save!

    render json: {
      success: true,
      data: listing_json(@listing)
    }
  end

  def destroy
    @listing.destroy!
    render json: {
      success: true,
      message: "Listing deleted successfully"
    }
  end

  def create
    name = params.require(:name)
    location = params.require(:location)
    price = params.require(:price)
    pictures = params[:pictures]

    picture_urls = pictures.present? ? ImageUploader.upload_multiple_images(pictures) : []

    listing = current_user.owned_listings.build(
      name: name,
      location: location,
      price: price,
      pictures: picture_urls
    )
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

  def authorize_listing
    raise ApiError.new("Unauthorized", status: :unauthorized) unless @listing.owner_id == current_user.id
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
