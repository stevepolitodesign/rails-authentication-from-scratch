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

  test "should render buttons to delete specific active sessions" do
    login @confirmed_user

    get account_path

    assert_select "input[type='submit']" do
      assert_select "[value=?]", "Log out of all other sessions"
    end
    assert_match destroy_all_active_sessions_path, @response.body

    assert_select "table" do
      assert_select "input[type='submit']" do
        assert_select "[value=?]", "Sign Out"
      end
    end
    assert_match active_session_path(@confirmed_user.active_sessions.last), @response.body
  end
end
