class RegistrationsController < ApplicationController
  before_action :redirect_logged_in, only: [:new, :create]

  rate_limit to: 5, within: 10.minutes, only: :create, store: AUTH_RATE_LIMIT_STORE, name: 'signup', with: -> { rate_limited }

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      reset_session
      session[:user_id] = @user.id
      redirect_to user_path(@user), notice: t('flash.registered')
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def rate_limited
    @user = User.new
    response.set_header('Retry-After', '600')
    flash.now[:alert] = t('flash.rate_limited')
    render :new, status: :too_many_requests
  end

  def redirect_logged_in
    redirect_to user_path(current_user) if logged_in?
  end

  def user_params
    params.require(:user).permit(:username, :email, :password, :password_confirmation)
  end
end
