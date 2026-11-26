require 'test_helper'

class GithubOauthFlowTest < ActionDispatch::IntegrationTest
  teardown do
    Rails.application.env_config.delete('omniauth.auth')
    Rails.application.env_config.delete('omniauth.params')
  end

  test 'GitHub callback creates and reuses an account' do
    callback
    identity = OauthIdentity.find_by!(provider: 'github', uid: 'github-flow-1')
    assert_redirected_to user_path(identity.user)
    delete logout_path
    assert_no_difference 'User.count' do
      callback
    end
    assert_redirected_to user_path(identity.user)
  end

  test 'GitHub can be connected to a logged in local user' do
    user = User.create!(username: 'local-gh', email: 'local-gh@example.test', password: 'TestingPass123')
    post login_path, params: { email: user.email, password: 'TestingPass123' }
    callback(intent: 'link')
    assert_redirected_to account_connections_path
    assert_equal 'github-flow-1', user.oauth_identities.find_by!(provider: 'github').uid
  end

  private

  def callback(intent: 'login')
    Rails.application.env_config['omniauth.auth'] = {
      'provider' => 'github', 'uid' => 'github-flow-1',
      'info' => { 'nickname' => 'gh-flow', 'email' => 'gh-flow@example.test' },
      'extra' => { 'all_emails' => [{ 'email' => 'gh-flow@example.test', 'primary' => true, 'verified' => true }] }
    }
    Rails.application.env_config['omniauth.params'] = { 'intent' => intent }
    get oauth_callback_path('github')
  end
end
