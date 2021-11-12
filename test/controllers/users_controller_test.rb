require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @confirmed_user = User.create!(email: "confirmed_user@example.com", password: "password", password_confirmation: "password", confirmed_at: Time.current)
  end

  test "should load sign up page for anonymous users" do
    get sign_up_path
    assert_response :ok
  end

  test "should redirect authenticated users from signing up" do
    login @confirmed_user

    get sign_up_path
    assert_redirected_to root_path

    assert_no_difference("User.count") do
      post sign_up_path, params: {
        user: {
          email: "some_unique_email@example.com",
          password: "password",
          password_confirmation: "password",
        }
      }
    end
  end

  test "should create user and send confirmation instructions" do
    assert_difference("User.count", 1) do
      assert_emails 1 do
        post sign_up_path, params: {
          user: {
            email: "some_unique_email@example.com",
            password: "password",
            password_confirmation: "password",
          }
        }
      end
    end

    assert_redirected_to root_path
    assert_not_nil flash[:notice]
  end

  test "should handle errors when signing up" do
    assert_no_difference("User.count") do
      assert_no_emails do
        post sign_up_path, params: {
          user: {
            email: "some_unique_email@example.com",
            password: "password",
            password_confirmation: "wrong_password",
          }
        }
      end
    end
  end

  test "should edit user" do
    flunk
  end

  test "should not be able to edit other users" do
    flunk
  end

  test "should delete user" do
    flunk
  end

end
