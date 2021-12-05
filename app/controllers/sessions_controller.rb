class SessionsController < ApplicationController
  before_action :redirect_if_authenticated, only: [:create, :new]

  def create
    @user = User.find_by(email: params[:user][:email].downcase)
    
    render_new_with_alert unless @user
    
    if @user.unconfirmed?
      redirect_to new_confirmation_path, alert: "You must confirm your email before you can sign in."
    elsif @user.authenticate(params[:user][:password])
      login @user
      redirect_to root_path, notice: "Signed in."
    else
      render_new_with_alert
    end
  end

  def destroy
    logout
    redirect_to root_path, notice: "Singed out."
  end

  def new
  end
  
  private
  
  def render_new_with_alert
    flash[:alert] = "Incorrect email or password."
    render :new
  end
end
