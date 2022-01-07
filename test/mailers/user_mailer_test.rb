require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  setup do
    @user = User.create!(email: "some_unique_email@example.com", password: "password", password_confirmation: "password")
  end

  test "confirmation" do
    confirmation_token = @user.generate_confirmation_token
    mail = UserMailer.confirmation(@user, confirmation_token)
    assert_equal "Confirmation Instructions", mail.subject
    assert_equal [@user.email], mail.to
    assert_equal [User::MAILER_FROM_EMAIL], mail.from
    assert_match confirmation_token, mail.body.encoded
  end

  test "password_reset" do
    mail = UserMailer.password_reset(@user)
    assert_equal "Password Reset Instructions", mail.subject
    assert_equal [@user.email], mail.to
    assert_equal [User::MAILER_FROM_EMAIL], mail.from
    assert_match @user.password_reset_token, mail.body.encoded
  end
end
