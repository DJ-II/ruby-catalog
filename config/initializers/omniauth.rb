require 'omniauth'
require 'omniauth-google-oauth2'
require 'omniauth-facebook'
require 'omniauth-github'
require 'uri'

OmniAuth.config.allowed_request_methods = [:post]
OmniAuth.config.request_validation_phase = OmniAuth::AuthenticityTokenProtection.new(key: :_csrf_token)
OmniAuth.config.logger = Rails.logger

app_url = ENV['APP_URL'].to_s.strip
if Rails.env.production? && (ENV['GOOGLE_CLIENT_ID'].present? || ENV['FACEBOOK_APP_ID'].present? || ENV['GITHUB_CLIENT_ID'].present?) && app_url.blank?
  raise 'Set APP_URL to your public HTTPS origin before enabling OAuth in production'
end
if app_url.present?
  uri = URI.parse(app_url)
  if uri.host.present? && %w[http https].include?(uri.scheme) && (uri.scheme == 'https' || Rails.env.development? || Rails.env.test?)
    OmniAuth.config.full_host = "#{uri.scheme}://#{uri.host}#{uri.port == uri.default_port ? '' : ":#{uri.port}"}"
  else
    raise 'APP_URL must be an absolute HTTPS URL outside development/test'
  end
end

Rails.application.config.middleware.use OmniAuth::Builder do
  if ENV['GOOGLE_CLIENT_ID'].present? && ENV['GOOGLE_CLIENT_SECRET'].present?
    provider :google_oauth2, ENV.fetch('GOOGLE_CLIENT_ID'), ENV.fetch('GOOGLE_CLIENT_SECRET'), scope: 'email,profile', prompt: 'select_account'
  end

  if ENV['GITHUB_CLIENT_ID'].present? && ENV['GITHUB_CLIENT_SECRET'].present?
    provider :github, ENV.fetch('GITHUB_CLIENT_ID'), ENV.fetch('GITHUB_CLIENT_SECRET'), scope: 'user:email'
  end

  if ENV['FACEBOOK_APP_ID'].present? && ENV['FACEBOOK_APP_SECRET'].present?
    provider :facebook, ENV.fetch('FACEBOOK_APP_ID'), ENV.fetch('FACEBOOK_APP_SECRET'), scope: 'email', info_fields: 'id,name,email'
  end
end
