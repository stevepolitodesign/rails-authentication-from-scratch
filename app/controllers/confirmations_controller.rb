class ConfirmationsController < ApplicationController

  def create
    # TODO: Prevent authenticated users from access this action
    @user = User.find_by(email: params[:user][:email])

    if @user && @user.unconfirmed?
      @user.send_confirmation_email!
      redirect_to root_path, notice: "Check your email for confirmation instructions."
    else
      redirect_to new_confirmation_path, alert: "We could not find a user with that email or that email has already been confirmed."
    end
  end

  def edit
    # TODO: Prevent authenticated users from access this action
    @user = User.find_by(confirmation_token: params[:confirmation_token])

    if @user && @user.confirmation_token_has_not_expired?
      @user.confirm!
      # TODO: authenticate @user and create session
      redirect_to root_path, notice: "Your account has been confirmed."
    else
      redirect_to new_confirmation_path, alert: "Invalid token."
    end
  end

  def new
    # TODO: Prevent authenticated users from access this action
    @user = User.new
  end

end
