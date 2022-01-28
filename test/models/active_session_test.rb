require "test_helper"

class ActiveSessionTest < ActiveSupport::TestCase
  setup do
    @user = User.new(email: "unique_email@example.com", password: "password", password_confirmation: "password")
    @active_session = @user.active_sessions.build
  end

  test "should be valid" do
    assert @active_session.valid?
  end

  test "should have a user" do
    @active_session.user = nil

    assert_not @active_session.valid?
  end
end
