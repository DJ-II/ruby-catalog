require 'digest'
require 'securerandom'
require 'uri'
require 'set'

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
    attempts ||= 0
    existing = OauthIdentity.includes(:user).find_by(provider: @provider, uid: @uid)
    return existing.user if existing
    email = email_for_new_user
    raise EmailAlreadyUsed if User.where('lower(email) = ?', email.downcase).exists?
    password = SecureRandom.hex(32)
    User.transaction(requires_new: true) do
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
  rescue ActiveRecord::RecordInvalid => error
    raise unless error.record.is_a?(User) && error.record.errors.added?(:username, :taken)
    attempts += 1
    retry if attempts < 3
    raise
  rescue ActiveRecord::RecordNotUnique => error
    existing = OauthIdentity.includes(:user).find_by(provider: @provider, uid: @uid)
    return existing.user if existing
    constraint = error.cause.result&.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME) if error.cause.respond_to?(:result)
    if constraint == 'index_users_on_lower_username'
      attempts += 1
      retry if attempts < 3
    end
    raise EmailAlreadyUsed if constraint == 'index_users_on_lower_email'
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
    verified = (@provider == 'google_oauth2' && verified_google_email?) || (@provider == 'github' && verified_github_email?(supplied))
    return supplied if verified && supplied.match?(URI::MailTo::EMAIL_REGEXP)
    "social_#{Digest::SHA256.hexdigest("#{@provider}:#{@uid}")[0,24]}@oauth.inventoryhub.invalid"
  end

  def verified_google_email?
    raw = @extra['raw_info'] || {}
    claims = @extra['id_info'] || {}
    [raw['email_verified'], claims['email_verified'], @info['email_verified']].any? { |v| v == true || v == 'true' }
  end

  def verified_github_email?(email)
    entries = @extra['all_emails']
    return false unless entries.is_a?(Array) && email.present?
    entries.any? do |entry|
      entry.is_a?(Hash) &&
        entry['primary'] == true && entry['verified'] == true &&
        entry['email'].to_s.strip.downcase == email
    end
  end

  def new_username
    display = if @provider == 'github'
      @info['nickname'].presence || @info['name'].presence
    else
      @info['name'].presence || @info['nickname'].presence
    end
    base = display.to_s.gsub(/[^\p{L}\p{N}_-]+/u, '_').gsub(/\A[_-]+|[_-]+\z/u, '')[0, 40]
    base = 'member' if base.length < 3
    prefix = ActiveRecord::Base.sanitize_sql_like(base.downcase)
    taken = User.where('lower(username) = :base OR lower(username) LIKE :prefix', base: base.downcase, prefix: "#{prefix}\\_%").pluck(:username).map(&:downcase).to_set
    return base unless taken.include?(base.downcase)
    number = 2
    number += 1 while taken.include?("#{base.downcase}_#{number}")
    "#{base}_#{number}"
  end
end
