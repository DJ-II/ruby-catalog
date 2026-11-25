require 'digest'
require 'securerandom'
require 'uri'

class OauthAccount
  class InvalidIdentity < StandardError; end
  class EmailAlreadyUsed < StandardError; end
  class IdentityAlreadyLinked < StandardError; end
  class ProviderAlreadyLinked < StandardError; end

  def initialize(auth)
    @provider = auth&.dig('provider').to_s
    @uid = auth&.dig('uid').to_s
    @info = auth&.dig('info') || {}
    @extra = auth&.dig('extra') || {}
    raise InvalidIdentity unless OauthIdentity::PROVIDERS.include?(@provider) && @uid.present? && @uid.length <= 255
  end

  def authenticate_or_register
    existing = OauthIdentity.includes(:user).find_by(provider: @provider, uid: @uid)
    return existing.user if existing

    email = email_for_new_user
    raise EmailAlreadyUsed if User.where('lower(email) = ?', email.downcase).exists?

    password = SecureRandom.hex(32)
    User.transaction do
      user = User.create!(
        username: new_username,
        email: email,
        password: password,
        password_confirmation: password,
        password_login_enabled: false
      )
      user.oauth_identities.create!(provider: @provider, uid: @uid)
      user
    end
  rescue ActiveRecord::RecordNotUnique
    existing = OauthIdentity.includes(:user).find_by(provider: @provider, uid: @uid)
    return existing.user if existing
    raise IdentityAlreadyLinked
  end

  def link_to!(user)
    existing = OauthIdentity.find_by(provider: @provider, uid: @uid)
    raise IdentityAlreadyLinked if existing && existing.user_id != user.id
    return existing if existing
    raise ProviderAlreadyLinked if user.oauth_identities.exists?(provider: @provider)

    user.oauth_identities.create!(provider: @provider, uid: @uid)
  rescue ActiveRecord::RecordNotUnique
    raise IdentityAlreadyLinked
  end

  private

  def email_for_new_user
    supplied = @info['email'].to_s.strip.downcase
    return supplied if @provider == 'google_oauth2' && verified_google_email? && supplied.match?(URI::MailTo::EMAIL_REGEXP)

    "social_#{Digest::SHA256.hexdigest("#{@provider}:#{@uid}")[0,24]}@oauth.inventoryhub.invalid"
  end

  def verified_google_email?
    raw = @extra['raw_info'] || {}
    claims = @extra['id_info'] || {}
    [raw['email_verified'], claims['email_verified'], @info['email_verified']].any? { |v| v == true || v == 'true' }
  end

  def new_username
    display = @info['name'].presence || @info['nickname'].presence || 'member'
    base = display.to_s.gsub(/[^\p{L}\p{N}_-]+/u, '_').gsub(/\A[_-]+|[_-]+\z/u, '')[0, 18]
    base = 'member' if base.blank?
    prefix = @provider == 'facebook' ? 'fb' : 'google'
    suffix = Digest::SHA256.hexdigest("#{@provider}:#{@uid}")[0, 12]
    "#{prefix}_#{base}_#{suffix}"
  end
end
