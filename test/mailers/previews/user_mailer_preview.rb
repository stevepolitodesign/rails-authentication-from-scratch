# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/user_mailer/confirmation
  def confirmation
    @unconfirmed_user = User.find_or_create_by!(email: "unconfirmed_user@example.com")
    UserMailer.confirmation(@unconfirmed_user)
  end

end
