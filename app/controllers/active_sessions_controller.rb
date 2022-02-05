class ActiveSessionsController < ApplicationController
  before_action :authenticate_user!

  def destroy
    @active_session = current_user.active_sessions.find(params[:id])

    @active_session.destroy

    if current_user
      redirect_to account_path, notice: "Session deleted."
    else
      forget_active_session
      reset_session
      redirect_to root_path, notice: "Signed out."
    end
  end

  def destroy_all
    forget_active_session
    current_user.active_sessions.destroy_all
    reset_session

    redirect_to root_path, notice: "Signed out."
  end
end
