# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/user_mailer/confirmation
  def confirmation
    @unconfirmed_user = User.find_by(email: "unconfirmed_user@example.com") || User.create!(email: "unconfirmed_user@example.com", password: "password", password_confirmation: "password")
    UserMailer.confirmation(@unconfirmed_user)
  end

  # Preview this email at http://localhost:3000/rails/mailers/user_mailer/password_reset
  def password_reset
    @password_reset_user = User.find_by(email: "password_reset_user@example.com") || User.create!(email: "password_reset_user@example.com", password: "password", password_confirmation: "password")
    UserMailer.password_reset(@password_reset_user)
  end
end
