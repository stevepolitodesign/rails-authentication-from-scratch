require "test_helper"

class FriendlyRedirectsTest < ActionDispatch::IntegrationTest
  setup do
    @confirmed_user = User.create!(email: "confirmed_user@example.com", password: "password", password_confirmation: "password", confirmed_at: Time.current)
  end

  test "redirect to requested url after sign in" do
    get account_path

    assert_redirected_to login_path
    login(@confirmed_user)

    assert_redirected_to account_path
  end

  test "redirects to root path after sign in" do
    get login_path
    login(@confirmed_user)

    assert_redirected_to root_path
  end
end
