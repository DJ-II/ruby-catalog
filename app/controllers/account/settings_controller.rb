module Account
  class SettingsController < ApplicationController
    before_action :require_login
    helper_method :deletion_verified?

    def show
      load_settings
    end

    def update
      @user = User.find(current_user.id)
      if @user.update(username: params.require(:user).permit(:username)[:username])
        redirect_to account_settings_path, notice: t('account_settings.username_saved'), status: :see_other
      else
        load_settings
        render :show, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotUnique
      @user.errors.add(:username, :taken)
      load_settings
      render :show, status: :unprocessable_entity
    end

    def destroy
      unless params[:confirmation].to_s == 'DELETE'
        return redirect_to account_settings_path, alert: t('account_settings.confirmation_invalid'), status: :see_other
      end
      user = current_user
      deleted = user.with_lock do
        verified = deletion_verified? || (user.password_login_enabled? && user.authenticate(params[:current_password].to_s))
        if verified
          user.destroy!
          true
        else
          false
        end
      end
      unless deleted
        return redirect_to account_settings_path, alert: t('account_settings.reauth_required'), status: :see_other
      end
      reset_session
      cookies.delete(:inventoryhub_locale)
      cookies.delete(:inventoryhub_theme)
      redirect_to root_path, notice: t('account_settings.deleted'), status: :see_other
    end

    private

    def load_settings
      @user ||= current_user
      @connections = current_user.oauth_identities.order(:provider).to_a
    end

    def deletion_verified?
      proof = session[:account_deletion_proof]
      return false unless proof.is_a?(Hash) && proof['user_id'] == current_user.id
      age = Time.current.to_i - proof['at'].to_i
      return false unless age.between?(0, 300)
      current_user.oauth_identities.exists?(id: proof['identity_id'])
    end
  end
end
