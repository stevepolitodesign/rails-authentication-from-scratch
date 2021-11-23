class PasswordsController < ApplicationController
  before_action :redirect_if_authenticated

  def create
    @user = User.find_by(email: params[:user][:email].downcase)
    if @user.present?
      if @user.confirmed?
        @user.send_password_reset_email!
        redirect_to root_path, notice: "If that user exists we've sent instructions to their email."
      else
        redirect_to new_confirmation_path, alert: "Please confirm your email first."
      end
    else
      redirect_to root_path, notice: "If that user exists we've sent instructions to their email."
    end
  end

  def edit
    @user = User.find_by(password_reset_token: params[:password_reset_token])
    if @user && @user.unconfirmed?
      redirect_to new_confirmation_path, alert: "You must confirm your email before you can sign in."
    elsif @user.nil? || @user.password_reset_token_has_expired?
      redirect_to new_password_path, alert: "Invalid or expired token."
    end
  end

  def new
  end

  def update
    @user = User.find_by(password_reset_token: params[:password_reset_token])
    if @user
      if @user.unconfirmed?
        redirect_to new_confirmation_path, alert: "You must confirm your email before you can sign in."
      elsif @user.password_reset_token_has_expired?
        redirect_to new_password_path, alert: "Incorrect email or password."
      elsif @user.update(password_params)
        redirect_to login_path, notice: "Signed in."
      else
        flash[:alert] = @user.errors.full_messages.to_sentence
        render :edit        
      end
    else
      flash[:alert] = "Incorrect email or password."
      render :new
    end
  end

  private

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
