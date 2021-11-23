class User < ApplicationRecord
  CONFIRMATION_TOKEN_EXPIRATION_IN_SECONDS = 10.minutes.to_i
  MAILER_FROM_EMAIL = "no-reply@example.com"
  PASSWORD_RESET_TOKEN_EXPIRATION_IN_SECONDS = 10.minutes.to_i
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i

  has_secure_password
  has_secure_token :confirmation_token
  has_secure_token :password_reset_token

  before_save :downcase_email

  validates :email, format: { with: VALID_EMAIL_REGEX }, presence: true, uniqueness: true

  def confirm!
    self.update_columns(confirmed_at: Time.current)
  end

  def confirmed?
    self.confirmed_at.present?
  end

  def confirmation_token_has_not_expired?
    return false if self.confirmation_sent_at.nil?
    (Time.current - self.confirmation_sent_at) <= User::CONFIRMATION_TOKEN_EXPIRATION_IN_SECONDS
  end

  def password_reset_token_has_expired?
    return true if self.password_reset_sent_at.nil?
    (Time.current - self.password_reset_sent_at) >= User::PASSWORD_RESET_TOKEN_EXPIRATION_IN_SECONDS
  end  

  def send_confirmation_email!
    self.regenerate_confirmation_token
    self.update_columns(confirmation_sent_at: Time.current)
    UserMailer.confirmation(self).deliver_now
  end

  def send_password_reset_email!
    self.regenerate_password_reset_token
    self.update_columns(password_reset_sent_at: Time.current)
    UserMailer.password_reset(self).deliver_now
  end

  def unconfirmed?
    self.confirmed_at.nil?
  end

  private

  def downcase_email
    self.email = self.email.downcase
  end
end
