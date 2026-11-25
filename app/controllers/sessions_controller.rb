class SessionsController < ApplicationController
  def new; end

  def create
    user = User.authenticate_by(email: params[:email].to_s.strip.downcase, password: params[:password].to_s)
    if user&.blocked?
      redirect_to login_path, alert: t('flash.blocked')
    elsif user&.password_login_enabled?
      reset_session
      session[:user_id] = user.id
      redirect_to user_path(user), notice: t('flash.logged_in')
    else
      flash.now[:alert] = t('flash.invalid_login')
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to root_path, notice: t('flash.logged_out')
  end
end
