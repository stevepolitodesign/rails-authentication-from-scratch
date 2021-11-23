class UserMailer < ApplicationMailer
  default from: User::MAILER_FROM_EMAIL

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.user_mailer.confirmation.subject
  #
  def confirmation(user)
    @user = user

    mail to: @user.email, subject: "Confirmation Instructions"
  end

  def password_reset(user)
    @user = user

    mail to: @user.email, subject: "Password Reset Instructions"
  end
end
