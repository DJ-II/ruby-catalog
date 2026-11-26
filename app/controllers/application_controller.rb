class ApplicationController < ActionController::Base
  AUTH_RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new(size: 8.megabytes)
  allow_browser versions: :modern
  around_action :switch_locale
  helper_method :current_user, :logged_in?, :can_manage?, :can_write?, :oauth_provider_enabled?, :preferred_theme

  private

  def current_user
    return @current_user if defined?(@current_user)
    candidate = User.find_by(id: session[:user_id]) if session[:user_id].present?
    @current_user = candidate if candidate && !candidate.blocked?
  end

  def logged_in?
    current_user.present?
  end

  def require_login
    redirect_to login_path, alert: t('flash.login_required') unless logged_in?
  end

  def require_admin
    redirect_to root_path, alert: t('flash.forbidden') unless current_user&.admin?
  end

  def can_manage?(inventory)
    inventory.editable_by?(current_user)
  end

  def can_write?(inventory)
    inventory.writable_by?(current_user)
  end

  def oauth_provider_enabled?(provider)
    case provider.to_s
    when 'google_oauth2' then ENV['GOOGLE_CLIENT_ID'].present? && ENV['GOOGLE_CLIENT_SECRET'].present?
    when 'github' then ENV['GITHUB_CLIENT_ID'].present? && ENV['GITHUB_CLIENT_SECRET'].present?
    when 'facebook' then ENV['FACEBOOK_APP_ID'].present? && ENV['FACEBOOK_APP_SECRET'].present?
    else false
    end
  end

  def preferred_theme
    selected = current_user&.theme || cookies[:inventoryhub_theme]
    User::SUPPORTED_THEMES.include?(selected) ? selected : 'light'
  end

  def switch_locale(&action)
    requested = params[:lang].presence
    locale = requested || current_user&.locale || cookies[:inventoryhub_locale] || 'en'
    locale = 'en' unless User::SUPPORTED_LOCALES.include?(locale)
    cookies.permanent[:inventoryhub_locale] = locale if requested.present? && !logged_in?
    Time.use_zone('Europe/Warsaw') { I18n.with_locale(locale, &action) }
  end
end
