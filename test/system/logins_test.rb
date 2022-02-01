require "application_system_test_case"

class LoginsTest < ApplicationSystemTestCase
  setup do
    @confirmed_user = User.create!(email: "confirmed_user@example.com", password: "password", password_confirmation: "password", confirmed_at: Time.current)
  end

  test "should login and create active session if confirmed" do
    visit login_path

    fill_in "Email", with: @confirmed_user.email
    fill_in "Password", with: @confirmed_user.password
    click_on "Sign In"

    assert_not_nil @confirmed_user.active_sessions.last.user_agent
    assert_not_nil @confirmed_user.active_sessions.last.ip_address
  end
end
