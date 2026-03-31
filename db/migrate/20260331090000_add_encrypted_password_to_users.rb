class AddEncryptedPasswordToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :encrypted_password, :string, null: false, default: ""
    remove_column :users, :password, :string
  end

  def down
    add_column :users, :password, :string
    remove_column :users, :encrypted_password, :string
  end
end
