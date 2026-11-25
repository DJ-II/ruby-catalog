class OauthCallbacksController < ApplicationController
  def callback
    auth = request.env['omniauth.auth']
    if auth.blank? || auth['provider'].to_s != params[:provider].to_s
      return redirect_to login_path, alert: t('oauth.failed')
    end

    account = OauthAccount.new(auth)
    intent = request.env.dig('omniauth.params', 'intent').to_s

    if intent == 'link'
      return redirect_to login_path, alert: t('flash.login_required') unless logged_in?
      account.link_to!(current_user)
      redirect_to account_connections_path, notice: t('oauth.linked')
    elsif intent == 'login' || intent.blank?
      return redirect_to account_connections_path, alert: t('oauth.use_link') if logged_in?
      user = account.authenticate_or_register
      return redirect_to login_path, alert: t('flash.blocked') if user.blocked?

      reset_session
      session[:user_id] = user.id
      redirect_to user_path(user), notice: t('flash.logged_in')
    else
      redirect_to login_path, alert: t('oauth.failed')
    end
  rescue OauthAccount::EmailAlreadyUsed
    redirect_to login_path, alert: t('oauth.email_exists')
  rescue OauthAccount::IdentityAlreadyLinked, OauthAccount::ProviderAlreadyLinked
    redirect_to(logged_in? ? account_connections_path : login_path, alert: t('oauth.already_linked'))
  rescue OauthAccount::InvalidIdentity, ActiveRecord::RecordInvalid
    redirect_to login_path, alert: t('oauth.failed')
  end

  def failure
    redirect_to login_path, alert: t('oauth.failed')
  end
end
