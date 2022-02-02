require "test_helper"

class ActiveSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @confirmed_user = User.create!(email: "confirmed_user@example.com", password: "password", password_confirmation: "password", confirmed_at: Time.current)
  end

  test "should destroy all active sessions" do
    login @confirmed_user
    @confirmed_user.active_sessions.create!

    assert_difference("ActiveSession.count", -2) do
      delete destroy_all_active_sessions_path
    end

    assert_redirected_to root_path
    assert_nil current_user
    assert_not_nil flash[:notice]
  end

  test "should destroy another session" do
    login @confirmed_user
    @confirmed_user.active_sessions.create!

    assert_difference("ActiveSession.count", -1) do
      delete active_session_path(@confirmed_user.active_sessions.last)
    end

    assert_redirected_to account_path
    assert_not_nil current_user
    assert_not_nil flash[:notice]
  end

  test "should destroy current session" do
    login @confirmed_user

    assert_difference("ActiveSession.count", -1) do
      delete active_session_path(@confirmed_user.active_sessions.last)
    end

    assert_redirected_to root_path
    assert_nil current_user
    assert_not_nil flash[:notice]
  end
end
