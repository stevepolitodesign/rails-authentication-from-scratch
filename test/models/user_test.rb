require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @user = User.new(email: "unique_email@example.com")
  end

  test "should be valid" do
    assert @user.valid?
  end

  test "should have email" do
    @user.email = nil
    assert_not @user.valid?
  end

  test "email should be unique" do
    @user.save!
    @invalid_user = User.new(email: @user.email)

    assert_not @invalid_user.valid?
  end

  test "email should be saved as lowercase" do
    email = "unique_email@example.com"

    @user = User.new(email: email.upcase)
    @user.save!

    assert_equal email.downcase, @user.email
  end

  test "email should be valid" do
    invalid_emails = %w(foo foo@ foo@bar.)

    invalid_emails.each do |invalid_email|
      @user.email = invalid_email
      assert_not @user.valid?
    end
  end
end
