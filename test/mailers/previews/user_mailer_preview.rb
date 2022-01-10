# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/user_mailer/confirmation
  def confirmation
    @unconfirmed_user = User.find_by(email: "unconfirmed_user@example.com") || User.create!(email: "unconfirmed_user@example.com", password: "password", password_confirmation: "password")
    @unconfirmed_user.update!(confirmed_at: nil)
    confirmation_token = @unconfirmed_user.generate_confirmation_token
    UserMailer.confirmation(@unconfirmed_user, confirmation_token)
  end

  # Preview this email at http://localhost:3000/rails/mailers/user_mailer/password_reset
  def password_reset
    @password_reset_user = User.find_by(email: "password_reset_user@example.com") || User.create!(email: "password_reset_user@example.com", password: "password", password_confirmation: "password", confirmed_at: Time.current)
    password_reset_token = @password_reset_user.generate_password_reset_token
    UserMailer.password_reset(@password_reset_user, password_reset_token)
  end
end
