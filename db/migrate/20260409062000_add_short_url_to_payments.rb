class AddShortUrlToPayments < ActiveRecord::Migration[8.1]
  def change
    add_column :payments, :short_url, :string
  end
end
