require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @confirmed_user = User.create!(email: "confirmed_user@example.com", password: "password", password_confirmation: "password", confirmed_at: 1.week.ago)
  end

  test "should get edit" do
    password_reset_token = @confirmed_user.generate_password_reset_token

    get edit_password_path(password_reset_token)
    assert_response :ok
  end

  test "should redirect from edit if password link expired" do
    password_reset_token = @confirmed_user.generate_password_reset_token

    travel_to 601.seconds.from_now
    get edit_password_path(password_reset_token)

    assert_redirected_to new_password_path
    assert_not_nil flash[:alert]
  end

  test "should redirect from edit if password link is incorrect" do
    get edit_password_path("not_a_real_token")

    assert_redirected_to new_password_path
    assert_not_nil flash[:alert]
  end

  test "should redirect from edit if user is not confirmed" do
    @confirmed_user.update!(confirmed_at: nil)
    password_reset_token = @confirmed_user.generate_password_reset_token

    get edit_password_path(password_reset_token)

    assert_redirected_to new_confirmation_path
    assert_not_nil flash[:alert]
  end

  test "should redirect from edit if user is authenticated" do
    password_reset_token = @confirmed_user.generate_password_reset_token

    login @confirmed_user

    get edit_password_path(password_reset_token)
    assert_redirected_to root_path
  end

  test "should get new" do
    get new_password_path
    assert_response :ok
  end

  test "should redirect from new if user is authenticated" do
    login @confirmed_user

    get new_password_path
    assert_redirected_to root_path
  end

  test "should send password reset mailer" do
    assert_emails 1 do
      post passwords_path, params: {
        user: {
          email: @confirmed_user.email.upcase
        }
      }
    end

    assert_redirected_to root_path
    assert_not_nil flash[:notice]
  end

  test "should update password" do
    password_reset_token = @confirmed_user.generate_password_reset_token

    put password_path(password_reset_token), params: {
      user: {
        password: "password",
        password_confirmation: "password"
      }
    }

    assert_redirected_to login_path
    assert_not_nil flash[:notice]
  end

  test "should handle errors" do
    password_reset_token = @confirmed_user.generate_password_reset_token

    put password_path(password_reset_token), params: {
      user: {
        password: "password",
        password_confirmation: "password_that_does_not_match"
      }
    }

    assert_not_nil flash[:alert]
  end

  test "should not update password if authenticated" do
    password_reset_token = @confirmed_user.generate_password_reset_token

    login @confirmed_user

    put password_path(password_reset_token), params: {
      user: {
        password: "password",
        password_confirmation: "password"

      }
    }

    get new_password_path
    assert_redirected_to root_path
  end
end
