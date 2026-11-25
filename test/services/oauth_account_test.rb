require 'test_helper'

class OauthAccountTest < ActiveSupport::TestCase
  def auth(provider: 'google_oauth2', uid: 'test-123', email: 'person@example.test', verified: true)
    {
      'provider' => provider,
      'uid' => uid,
      'info' => { 'name' => 'Pat Example', 'email' => email },
      'extra' => { 'raw_info' => { 'email_verified' => verified } }
    }
  end

  test 'creates a new Google account without enabling password login' do
    user = OauthAccount.new(auth).authenticate_or_register
    assert_equal 'person@example.test', user.email
    assert_not user.password_login_enabled?
    assert_equal 1, user.oauth_identities.count
    assert user.password_digest.present?
    assert_equal user, OauthAccount.new(auth).authenticate_or_register
    assert_equal 1, OauthIdentity.where(provider: 'google_oauth2', uid: 'test-123').count
  end

  test 'does not trust unverified Google email' do
    user = OauthAccount.new(auth(uid: 'unverified-123', verified: false)).authenticate_or_register
    assert_match(/\Asocial_[0-9a-f]{24}@oauth\.inventoryhub\.invalid\z/, user.email)
  end

  test 'does not trust Facebook email for account identity' do
    user = OauthAccount.new(auth(provider: 'facebook', uid: 'fb-123')).authenticate_or_register
    assert_match(/\Asocial_[0-9a-f]{24}@oauth\.inventoryhub\.invalid\z/, user.email)
    assert_not user.password_login_enabled?
  end

  test 'refuses silent linking to an existing local email account' do
    existing = User.create!(username: 'existing123', email: 'person@example.test', password: 'TestingPass123')
    assert_raises(OauthAccount::EmailAlreadyUsed) { OauthAccount.new(auth(uid: 'other-123')).authenticate_or_register }
    assert_equal 0, existing.oauth_identities.count
    assert_equal 1, User.where('lower(email) = ?', 'person@example.test').count
  end

  test 'supports explicit linking but not identity theft or two accounts for the same provider' do
    owner = User.create!(username: 'owner123', email: 'owner@example.test', password: 'TestingPass123')
    other = User.create!(username: 'other123', email: 'other@example.test', password: 'TestingPass123')
    OauthAccount.new(auth(uid: 'link-123')).link_to!(owner)
    assert_equal 1, owner.oauth_identities.count
    assert_raises(OauthAccount::IdentityAlreadyLinked) { OauthAccount.new(auth(uid: 'link-123')).link_to!(other) }
    assert_raises(OauthAccount::ProviderAlreadyLinked) { OauthAccount.new(auth(uid: 'link-456')).link_to!(owner) }
  end

  test 'rejects missing uid and unsupported provider' do
    assert_raises(OauthAccount::InvalidIdentity) { OauthAccount.new(auth(uid: '')) }
    assert_raises(OauthAccount::InvalidIdentity) { OauthAccount.new(auth(provider: 'developer')) }
  end

  test 'provider and uid pair has a unique database index' do
    owner = User.create!(username: 'first123', email: 'first@example.test', password: 'TestingPass123')
    other = User.create!(username: 'second123', email: 'second@example.test', password: 'TestingPass123')
    owner.oauth_identities.create!(provider: 'google_oauth2', uid: 'same')
    assert_raises(ActiveRecord::RecordNotUnique) do
      other.oauth_identities.insert_all!([{ provider: 'google_oauth2', uid: 'same', created_at: Time.current, updated_at: Time.current }])
    end
  end
end
