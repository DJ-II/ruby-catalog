module Account
  class ConnectionsController < ApplicationController
    before_action :require_login

    def index
      @connections = current_user.oauth_identities.order(:provider).to_a
    end

    def destroy
      provider = params[:provider].to_s
      return redirect_to account_connections_path, alert: t('oauth.failed') unless OauthIdentity::PROVIDERS.include?(provider)

      outcome = current_user.with_lock do
        identity = current_user.oauth_identities.find_by(provider: provider)
        if identity.nil?
          :not_connected
        elsif !current_user.password_login_enabled? && current_user.oauth_identities.count <= 1
          :last_method
        else
          identity.destroy!
          :unlinked
        end
      end

      if outcome == :unlinked
        redirect_to account_connections_path, notice: t('oauth.unlinked')
      else
        redirect_to account_connections_path, alert: t("oauth.#{outcome}")
      end
    end
  end
end
