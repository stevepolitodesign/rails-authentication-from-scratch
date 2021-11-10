class UsersController < ApplicationController

  def create
    # TODO: Prevent authenticated @user from accessing this action
    @user = User.new(user_params)
    if @user.save
      @user.send_confirmation_email!
      redirect_to root_path, notice: "Please check your email for confirmation instructions."
    else
      render :new
    end
  end

  def new
    # TODO: Prevent authenticated @user from accessing this action
    @user = User.new
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
