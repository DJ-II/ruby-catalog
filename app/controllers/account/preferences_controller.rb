module Account
  class PreferencesController < ApplicationController
    before_action :require_login, only: :show

    def show; end

    def update
      selected = params.require(:preferences).permit(:locale, :theme).to_h.symbolize_keys
      unless selected.present? && valid_choices?(selected)
        return render plain: t('preferences.invalid'), status: :unprocessable_entity
      end

      if current_user
        unless current_user.update(selected)
          return render plain: current_user.errors.full_messages.to_sentence, status: :unprocessable_entity
        end
      else
        cookies.permanent[:inventoryhub_locale] = selected[:locale] if selected.key?(:locale)
        cookies.permanent[:inventoryhub_theme] = selected[:theme] if selected.key?(:theme)
      end
      redirect_back fallback_location: (current_user ? account_preferences_path : root_path), status: :see_other
    end

    private

    def valid_choices?(selected)
      selected.keys.all? { |key| [:locale, :theme].include?(key) } &&
        (!selected.key?(:locale) || User::SUPPORTED_LOCALES.include?(selected[:locale])) &&
        (!selected.key?(:theme) || User::SUPPORTED_THEMES.include?(selected[:theme]))
    end
  end
end
