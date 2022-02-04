# TODO: Remove comment
# rails g migration move_remember_token_from_users_to_active_sessions
class MoveRememberTokenFromUsersToActiveSessions < ActiveRecord::Migration[6.1]
  def change
    remove_column :users, :remember_token
    add_column :active_sessions, :remember_token, :string, null: false

    add_index :active_sessions, :remember_token, unique: true
  end
end
