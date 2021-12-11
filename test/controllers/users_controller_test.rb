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
          password_confirmation: "password"
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
            password_confirmation: "password"
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
            password_confirmation: "wrong_password"
          }
        }
      end
    end
  end

  test "should get edit if authorized" do
    login(@confirmed_user)

    get account_path
    assert_response :ok
  end

  test "should redirect unauthorized user from editing account" do
    get account_path
    assert_redirected_to login_path
    assert_not_nil flash[:alert]
  end

  test "should edit email" do
    unconfirmed_email = "unconfirmed_user@example.com"
    current_email = @confirmed_user.email

    login(@confirmed_user)

    assert_emails 1 do
      put account_path, params: {
        user: {
          unconfirmed_email: unconfirmed_email,
          current_password: "password"
        }
      }
    end

    assert_not_nil flash[:notice]
    assert_equal current_email, @confirmed_user.reload.email
  end

  test "should not edit email if current_password is incorrect" do
    unconfirmed_email = "unconfirmed_user@example.com"
    current_email = @confirmed_user.email

    login(@confirmed_user)

    assert_no_emails do
      put account_path, params: {
        user: {
          unconfirmed_email: unconfirmed_email,
          current_password: "wrong_password"
        }
      }
    end

    assert_not_nil flash[:notice]
    assert_equal current_email, @confirmed_user.reload.email
  end

  test "should update password" do
    login(@confirmed_user)

    put account_path, params: {
      user: {
        current_password: "password",
        password: "new_password",
        password_confirmation: "new_password"
      }
    }

    assert_redirected_to root_path
    assert_not_nil flash[:notice]
  end

  test "should not update password if current_password is incorrect" do
    login(@confirmed_user)

    put account_path, params: {
      user: {
        current_password: "wrong_password",
        password: "new_password",
        password_confirmation: "new_password"
      }
    }

    assert_response :unprocessable_entity
  end

  test "should delete user" do
    login(@confirmed_user)

    delete account_path(@confirmed_user)

    assert_nil current_user
    assert_redirected_to root_path
    assert_not_nil flash[:notice]
  end
end
