require 'test_helper'

class OauthFlowTest < ActionDispatch::IntegrationTest
  setup do
    @local = User.create!(username: "local_#{SecureRandom.hex(4)}", email: "local_#{SecureRandom.hex(4)}@example.test", password: 'TestingPass123')
  end

  teardown do
    Rails.application.env_config.delete('omniauth.auth')
    Rails.application.env_config.delete('omniauth.params')
  end

  test 'unauthenticated OAuth callback creates a social account and starts a session' do
    callback(uid: 'google-new-100')
    user = OauthIdentity.find_by!(provider: 'google_oauth2', uid: 'google-new-100').user
    assert_redirected_to user_path(user)
    assert_not user.password_login_enabled?
    get user_path(user)
    assert_response :success
  end

  test 'a social account can use the same provider again' do
    callback(uid: 'return-100')
    user = OauthIdentity.find_by!(provider: 'google_oauth2', uid: 'return-100').user
    delete logout_path
    callback(uid: 'return-100')
    assert_redirected_to user_path(user)
    assert_equal 1, OauthIdentity.where(provider: 'google_oauth2', uid: 'return-100').count
  end

  test 'a social-only account is refused by password login even with a valid digest' do
    callback(uid: 'no-local-password-100')
    user = OauthIdentity.find_by!(provider: 'google_oauth2', uid: 'no-local-password-100').user
    user.update!(password: 'TestingPass123', password_confirmation: 'TestingPass123')
    delete logout_path
    post login_path, params: { email: user.email, password: 'TestingPass123' }
    assert_response :unprocessable_entity
  end

  test 'existing email is never automatically linked' do
    callback(uid: 'collision-100', email: @local.email)
    assert_redirected_to login_path
    assert_equal 0, @local.oauth_identities.count
  end

  test 'local account can explicitly connect Google, then disconnect it' do
    sign_in(@local)
    callback(uid: 'link-100', intent: 'link')
    assert_redirected_to account_connections_path
    assert_equal 1, @local.oauth_identities.count
    get account_connections_path
    assert_response :success
    delete account_connection_path('google_oauth2')
    assert_redirected_to account_connections_path
    assert_equal 0, @local.oauth_identities.count
  end

  test 'social-only account cannot disconnect its only provider' do
    callback(provider: 'facebook', uid: 'facebook-only-100')
    user = OauthIdentity.find_by!(provider: 'facebook', uid: 'facebook-only-100').user
    delete account_connection_path('facebook')
    assert_redirected_to account_connections_path
    assert_equal 1, user.oauth_identities.count
  end

  test 'social-only account can disconnect one provider after connecting a second' do
    callback(provider: 'facebook', uid: 'facebook-one-100')
    user = OauthIdentity.find_by!(provider: 'facebook', uid: 'facebook-one-100').user
    callback(uid: 'google-two-100', intent: 'link')
    assert_equal 2, user.oauth_identities.count
    delete account_connection_path('facebook')
    assert_equal 1, user.oauth_identities.count
  end

  test 'a blocked social account cannot sign in' do
    callback(uid: 'blocked-100')
    user = OauthIdentity.find_by!(provider: 'google_oauth2', uid: 'blocked-100').user
    user.update!(blocked_at: Time.current)
    delete logout_path
    callback(uid: 'blocked-100')
    assert_redirected_to login_path
    get account_connections_path
    assert_redirected_to login_path
  end

  test 'login flow cannot quietly connect a provider to an already signed in account' do
    sign_in(@local)
    callback(uid: 'accidental-100', intent: 'login')
    assert_redirected_to account_connections_path
    assert_equal 0, @local.oauth_identities.count
  end

  test 'link flow requires an authenticated account' do
    callback(uid: 'guest-link-100', intent: 'link')
    assert_redirected_to login_path
    assert_equal 0, OauthIdentity.where(uid: 'guest-link-100').count
  end

  test 'invalid callback data and failure redirect do not create users' do
    before_count = User.count
    Rails.application.env_config['omniauth.auth'] = { 'provider' => 'google_oauth2', 'uid' => '' }
    Rails.application.env_config['omniauth.params'] = { 'intent' => 'login' }
    get oauth_callback_path('google_oauth2')
    assert_redirected_to login_path
    get oauth_failure_path, params: { message: 'anything', strategy: 'google_oauth2' }
    assert_redirected_to login_path
    assert_equal before_count, User.count
  end

  private

  def sign_in(user)
    post login_path, params: { email: user.email, password: 'TestingPass123' }
    assert_response :redirect
  end

  def callback(provider: 'google_oauth2', uid:, email: 'newuser@example.test', intent: 'login')
    Rails.application.env_config['omniauth.auth'] = {
      'provider' => provider,
      'uid' => uid,
      'info' => { 'name' => 'Alex Example', 'email' => email },
      'extra' => { 'raw_info' => { 'email_verified' => true } }
    }
    Rails.application.env_config['omniauth.params'] = { 'intent' => intent }
    get oauth_callback_path(provider)
  end
end
