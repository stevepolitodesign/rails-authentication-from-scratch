class User < ApplicationRecord
  CONFIRMATION_TOKEN_EXPIRATION_IN_SECONDS = 10.minutes.to_i
  MAILER_FROM_EMAIL = "no-reply@example.com"
  PASSWORD_RESET_TOKEN_EXPIRATION_IN_SECONDS = 10.minutes.to_i

  attr_accessor :current_password

  has_secure_password
  has_secure_token :confirmation_token
  has_secure_token :password_reset_token
  has_secure_token :remember_token

  before_save :downcase_email
  before_save :downcase_unconfirmed_email

  validates :email, format: {with: URI::MailTo::EMAIL_REGEXP}, presence: true, uniqueness: true
  validates :unconfirmed_email, format: {with: URI::MailTo::EMAIL_REGEXP, allow_blank: true}
  validate :unconfirmed_email_must_be_available

  def confirm!
    if unconfirmed_email.present?
      update(email: unconfirmed_email, unconfirmed_email: nil)
    end
    update_columns(confirmed_at: Time.current)
  end

  def confirmed?
    confirmed_at.present?
  end

  def confirmable_email
    if unconfirmed_email.present?
      unconfirmed_email
    else
      email
    end
  end

  def confirmation_token_has_not_expired?
    return false if confirmation_sent_at.nil?
    (Time.current - confirmation_sent_at) <= User::CONFIRMATION_TOKEN_EXPIRATION_IN_SECONDS
  end

  def password_reset_token_has_expired?
    return true if password_reset_sent_at.nil?
    (Time.current - password_reset_sent_at) >= User::PASSWORD_RESET_TOKEN_EXPIRATION_IN_SECONDS
  end

  def send_confirmation_email!
    regenerate_confirmation_token
    update_columns(confirmation_sent_at: Time.current)
    UserMailer.confirmation(self).deliver_now
  end

  def send_password_reset_email!
    regenerate_password_reset_token
    update_columns(password_reset_sent_at: Time.current)
    UserMailer.password_reset(self).deliver_now
  end

  def reconfirming?
    unconfirmed_email.present?
  end

  def unconfirmed?
    !confirmed?
  end

  def unconfirmed_or_reconfirming?
    unconfirmed? || reconfirming?
  end

  private

  def downcase_email
    self.email = email.downcase
  end

  def downcase_unconfirmed_email
    return if unconfirmed_email.nil?
    self.unconfirmed_email = unconfirmed_email.downcase
  end

  def unconfirmed_email_must_be_available
    return if unconfirmed_email.nil?
    if User.find_by(email: unconfirmed_email.downcase)
      errors.add(:unconfirmed_email, "is already in use.")
    end
  end
end
