class ListingsController < ApplicationController
  before_action :set_listing, only: [ :show, :update, :destroy ]
  before_action :authorize_listing, only: [ :update, :destroy ]

  def index
    listings = Rails.cache.fetch("listings_index_#{current_user.id}", expires_in: 10.minutes) do
      Rails.logger.info("It was not a cache hit in listing index")
      Listing.where.not(owner_id: current_user.id).to_a
    end

    render json: {
      success: true,
      data: listings
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


  def my_listings
    listings = Rails.cache.fetch("listing_self_#{current_user.id}", expire_in: 20.minutes) do
      Listing.where(owner_id: current_user.id).to_a
    end

    render json: {
      success: true,
      data: listings
    }
  end

  def destroy
    @listing.destroy!
    render json: {
      success: true,
      message: "Listing deleted successfully"
    }
  end

  private

  def set_listing
    listing_id = params.require(:id)
    @listing = Rails.cache.fetch("listings_show_#{listing_id}", expires_in: 30.minutes) do
      Listing.find_by!(id: listing_id)
    end
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
