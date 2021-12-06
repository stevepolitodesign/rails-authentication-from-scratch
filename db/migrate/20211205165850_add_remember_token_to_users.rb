class AddRememberTokenToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :remember_token, :string, null: false
    add_index :users, :remember_token, unique: true
  end
end
