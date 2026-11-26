class RegistrationsController < ApplicationController
  before_action :redirect_logged_in, only: [:new, :create]

  before_action :enforce_rate_limit, only: :create

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

  def enforce_rate_limit
    retry_after = AuthRateLimit.consume(scope: 'signup', client_ip: AuthRateLimit.client_ip(request), limit: 5, period: 10.minutes)
    return unless retry_after
    @user = User.new
    response.set_header('Retry-After', retry_after.to_s)
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
