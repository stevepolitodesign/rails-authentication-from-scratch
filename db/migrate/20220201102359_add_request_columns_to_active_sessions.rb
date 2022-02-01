class AddRequestColumnsToActiveSessions < ActiveRecord::Migration[6.1]
  def change
    add_column :active_sessions, :user_agent, :string
    add_column :active_sessions, :ip_address, :string
  end
end
