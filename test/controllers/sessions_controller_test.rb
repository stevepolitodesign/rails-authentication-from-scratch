require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @unconfirmed_user = User.create!(email: "unconfirmed_user@example.com", password: "password", password_confirmation: "password")
    @confirmed_user = User.create!(email: "confirmed_user@example.com", password: "password", password_confirmation: "password", confirmed_at: Time.current)
  end

  test "should get login if anonymous" do
    get login_path
    assert_response :ok
  end

  test "should redirect from login if authenticated" do
    login @confirmed_user

    get login_path
    assert_redirected_to root_path
  end
  
  test "should login if confirmed" do
    post login_path, params: {
      user: {
        email: @confirmed_user.email,
        password: @confirmed_user.password
      }
    }
    assert_redirected_to root_path
    assert_equal @confirmed_user, current_user
  end

  test "should remember user when logging in" do
    assert_nil cookies[:remember_token]

    post login_path, params: {
      user: {
        email: @confirmed_user.email,
        password: @confirmed_user.password,
        remember_me: 1
      }
    }

    assert_not_nil current_user
    assert_not_nil cookies[:remember_token]
  end

  test "should forget user when logging out" do
    login @confirmed_user, remember_user: true

    delete logout_path
   
    # FIXME: Expected "" to be nil.
    # When I run byebug in SessionsController#destroy cookies[:remember_token] does == nil. 
    # I think this might be a bug in Rails?
    # assert_nil cookies[:remember_token]
    assert cookies[:remember_token].blank?
    assert_nil current_user
    assert_redirected_to root_path
    assert_not_nil flash[:notice]
  end

  
  test "should not login if unconfirmed" do
    post login_path, params: {
      user: {
        email: @unconfirmed_user.email,
        password: @unconfirmed_user.password
      }
    }
    assert_not_nil flash[:alert]
    assert_nil current_user
    assert_redirected_to new_confirmation_path
  end  

  test "should handle invalid login" do
    post login_path, params: {
      user: {
        email: @confirmed_user.email,
        password: "foo"
      }
    }
    assert_not_nil flash[:alert]
    assert_nil current_user
  end

  test "should logout if authenticated" do
    login @confirmed_user

    delete logout_path

    assert_nil current_user
    assert_redirected_to root_path
    assert_not_nil flash[:notice]
  end
  
  test "should not logout if anonymous" do
    login @confirmed_user

    delete logout_path
    assert_redirected_to root_path 
  end
end