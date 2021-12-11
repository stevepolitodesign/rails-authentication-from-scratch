class AddConfirmationAndPasswordColumnsToUsers < ActiveRecord::Migration[6.1]
  def change
    # This will be used to identify a user in a secure way. We don't ever want it to be empty.
    # This value will automatically be set on save.
    # https://api.rubyonrails.org/classes/ActiveRecord/SecureToken/ClassMethods.html#method-i-has_secure_token
    add_column :users, :confirmation_token, :string, null: false
    add_column :users, :confirmation_sent_at, :datetime
    add_column :users, :confirmed_at, :datetime

    # This will store the hashed value of the password. We don't ever want it to be empty.
    # https://api.rubyonrails.org/classes/ActiveModel/SecurePassword/ClassMethods.html#method-i-has_secure_password
    add_column :users, :password_digest, :string, null: false

    # This will ensure the confirmation_token is unique.
    add_index :users, :confirmation_token, unique: true
  end
end
