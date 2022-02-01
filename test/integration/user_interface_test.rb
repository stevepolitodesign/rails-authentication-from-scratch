require "test_helper"

class UserInterfaceTest < ActionDispatch::IntegrationTest
  setup do
    @confirmed_user = User.create!(email: "confirmed_user@example.com", password: "password", password_confirmation: "password", confirmed_at: Time.current)
  end

  test "should render active sessions on account page" do
    login @confirmed_user
    @confirmed_user.active_sessions.last.update!(user_agent: "Mozilla", ip_address: "123.457.789")

    get account_path

    assert_match "Mozilla", @response.body
    assert_match "123.457.789", @response.body
  end
end
