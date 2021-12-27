require "test_helper"

class UserTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @user = User.new(email: "unique_email@example.com", password: "password", password_confirmation: "password")
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

    @user = User.new(email: email.upcase, password: "password", password_confirmation: "password")
    @user.save!

    assert_equal email.downcase, @user.email
  end

  test "email should be valid" do
    invalid_emails = %w[foo foo@ foo@bar.]

    invalid_emails.each do |invalid_email|
      @user.email = invalid_email
      assert_not @user.valid?
    end
  end

  test "should respond to confirmed?" do
    assert_not @user.confirmed?

    @user.confirmed_at = Time.now

    assert @user.confirmed?
  end

  test "should respond to unconfirmed?" do
    assert @user.unconfirmed?

    @user.confirmed_at = Time.now

    assert_not @user.unconfirmed?
  end

  test "should respond to reconfirming?" do
    assert_not @user.reconfirming?

    @user.unconfirmed_email = "unconfirmed_email@example.com"

    assert @user.reconfirming?
  end

  test "should respond to unconfirmed_or_reconfirming?" do
    assert @user.unconfirmed_or_reconfirming?

    @user.unconfirmed_email = "unconfirmed_email@example.com"
    @user.confirmed_at = Time.now

    assert @user.unconfirmed_or_reconfirming?
  end

  test "should confirm email" do
    @user.save!
    original_confirmation_token = @user.confirmation_token

    freeze_time

    assert_nil @user.confirmation_sent_at

    assert_emails 1 do
      @user.send_confirmation_email!
    end

    assert_not_equal original_confirmation_token, @user.reload.confirmation_token
    assert_equal Time.now, @user.confirmation_sent_at
    assert_equal @user.email, ActionMailer::Base.deliveries.last.to[0]
  end

  test "should confirm unconfirmed_email" do
    @user.save!
    @user.update!(unconfirmed_email: "unconfirmed_email@example.com")
    previous_confirmation_token = @user.reload.confirmation_token

    freeze_time

    assert_emails 1 do
      @user.send_confirmation_email!
    end

    assert_not_equal previous_confirmation_token, @user.reload.confirmation_token
    assert_equal Time.now, @user.confirmation_sent_at
    assert_equal @user.unconfirmed_email, ActionMailer::Base.deliveries.last.to[0]
  end

  test "should respond to confirmation_token_is_valid?" do
    assert_not @user.confirmation_token_is_valid?

    @user.confirmation_sent_at = 1.minute.ago
    assert @user.confirmation_token_is_valid?

    @user.confirmation_sent_at = 601.seconds.ago
    assert_not @user.confirmation_token_is_valid?
  end

  test "should respond to send_password_reset_email!" do
    @user.save!
    original_password_reset_token = @user.password_reset_token

    freeze_time

    assert_nil @user.password_reset_sent_at

    assert_emails 1 do
      @user.send_password_reset_email!
    end

    assert_not_equal original_password_reset_token, @user.reload.password_reset_token
    assert_equal Time.now, @user.password_reset_sent_at
  end

  test "should respond to password_reset_token_has_expired?" do
    assert @user.password_reset_token_has_expired?

    @user.password_reset_sent_at = 1.minute.ago
    assert_not @user.password_reset_token_has_expired?

    @user.password_reset_sent_at = 601.seconds.ago
    assert @user.password_reset_token_has_expired?
  end

  test "should downcase unconfirmed_email" do
    email = "UNCONFIRMED_EMAIL@EXAMPLE.COM"
    @user.unconfirmed_email = email
    @user.save!

    assert_equal email.downcase, @user.unconfirmed_email
  end

  test "unconfirmed_email should be valid" do
    invalid_emails = %w[foo foo@ foo@bar.]

    invalid_emails.each do |invalid_email|
      @user.unconfirmed_email = invalid_email
      assert_not @user.valid?
    end
  end

  test "unconfirmed_email does not need to be available" do
    @user.save!
    @user.unconfirmed_email = @user.email
    assert @user.valid?
  end

  test ".confirm! should return false if already confirmed" do
    @confirmed_user = User.new(email: "unique_email@example.com", password: "password", password_confirmation: "password", confirmed_at: Time.current)

    assert_not @confirmed_user.confirm!
  end

  test ".confirm! should update email if reconfirming" do
    @reconfirmed_user = User.new(email: "unique_email@example.com", password: "password", password_confirmation: "password", confirmed_at: 1.week.ago, unconfirmed_email: "unconfirmed_email@example.com")
    new_email = @reconfirmed_user.unconfirmed_email

    freeze_time do
      @reconfirmed_user.confirm!

      assert_equal new_email, @reconfirmed_user.reload.email
      assert_nil @reconfirmed_user.reload.unconfirmed_email
      assert_equal Time.current, @reconfirmed_user.reload.confirmed_at
    end
  end

  test ".confirm! should not update email if already taken" do
    @confirmed_user = User.create!(email: "user1@example.com", password: "password", password_confirmation: "password")
    @reconfirmed_user = User.create!(email: "user2@example.com", password: "password", password_confirmation: "password", confirmed_at: 1.week.ago, unconfirmed_email: @confirmed_user.email)

    freeze_time do
      assert_not @reconfirmed_user.confirm!
    end
  end

  test ".confirm! should set confirmed_at" do
    @unconfirmed_user = User.create!(email: "unique_email@example.com", password: "password", password_confirmation: "password")

    freeze_time do
      @unconfirmed_user.confirm!

      assert_equal Time.current, @unconfirmed_user.reload.confirmed_at
    end
  end

  test "should set session_token on create" do
    @user.save!

    assert_not_nil @user.reload.session_token
  end
end
