module ImageUploader
  extend self

  def upload_multiple_images(files)
    return [] if files.blank?
    files_array = files.values

    pool = Concurrent::FixedThreadPool.new(10)

    futures = files_array.map do |file|
      Concurrent::Future.execute(executor: pool) do
        upload_image(file)
      end
    end

    # Wait for all uploads and get results
    urls = futures.map do |future|
      begin
        future.value
      rescue => e
        raise ApiError.new("Image upload failed: #{e.message}", status: :unprocessable_entity)
      end
    end.compact

    pool.shutdown
    pool.wait_for_termination

    urls
  end

  def upload_image(file)
    result = Cloudinary::Uploader.upload(file, {
      folder: "airbnb-listings",
      use_filename: true,
      unique_filename: true,
      resource_type: "auto",
      eager: [
        { width: 800, crop: "scale", quality: "auto", fetch_format: "auto" }
      ]
    })
    result["secure_url"]
  end
end
