require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  setup do
    @user = User.create!(email: "some_unique_email@example.com", password: "password", password_confirmation: "password")
  end

  test "confirmation" do
    mail = UserMailer.confirmation(@user)
    assert_equal "Confirmation Instructions", mail.subject
    assert_equal [@user.email], mail.to
    assert_equal [User::MAILER_FROM_EMAIL], mail.from
    assert_match @user.confirmation_token, mail.body.encoded
  end

end
