require 'test_helper'

class GithubOauthAccountTest < ActiveSupport::TestCase
  def github_auth(uid: 'github-123', email: 'github@example.test', verified: true, nickname: 'catalog-user')
    {
      'provider' => 'github', 'uid' => uid,
      'info' => { 'name' => 'Example Name', 'nickname' => nickname, 'email' => email },
      'extra' => { 'all_emails' => [{ 'email' => email, 'primary' => true, 'verified' => verified }] }
    }
  end

  test 'registers GitHub identity with verified primary email and nickname and reuses it' do
    user = OauthAccount.new(github_auth).authenticate_or_register
    assert_equal 'catalog-user', user.username
    assert_equal 'github@example.test', user.email
    assert_not user.password_login_enabled?
    assert_equal 'github', user.oauth_identities.first.provider
    assert_equal user, OauthAccount.new(github_auth).authenticate_or_register
    assert_equal 1, OauthIdentity.where(provider: 'github', uid: 'github-123').count
  end

  test 'unverified or absent email does not become the account email' do
    user = OauthAccount.new(github_auth(verified: false)).authenticate_or_register
    assert_match(/@oauth\.inventoryhub\.invalid\z/, user.email)
    other = OauthAccount.new(github_auth(uid: 'no-email', email: nil)).authenticate_or_register
    assert_match(/@oauth\.inventoryhub\.invalid\z/, other.email)
  end

  test 'verified GitHub email never silently links an existing local account' do
    local = User.create!(username: 'localuser', email: 'github@example.test', password: 'TestingPass123')
    assert_raises(OauthAccount::EmailAlreadyUsed) { OauthAccount.new(github_auth).authenticate_or_register }
    assert_empty local.oauth_identities
    OauthAccount.new(github_auth).link_to!(local)
    assert_equal local, OauthAccount.new(github_auth).authenticate_or_register
  end

  test 'username conflicts use short case insensitive numeric suffixes' do
    User.create!(username: 'CATALOG-USER', email: 'local@example.test', password: 'TestingPass123')
    first = OauthAccount.new(github_auth).authenticate_or_register
    second = OauthAccount.new(github_auth(uid: 'second', email: 'second@example.test')).authenticate_or_register
    assert_equal 'catalog-user_2', first.username
    assert_equal 'catalog-user_3', second.username
  end

  test 'Google uses readable names for new users without renaming existing users' do
    auth = { 'provider' => 'google_oauth2', 'uid' => 'google-new', 'info' => { 'name' => 'Pat Example', 'email' => 'pat@example.test' }, 'extra' => { 'raw_info' => { 'email_verified' => true } } }
    user = OauthAccount.new(auth).authenticate_or_register
    assert_equal 'Pat_Example', user.username
    user.update!(username: 'previous_name')
    assert_equal 'previous_name', OauthAccount.new(auth).authenticate_or_register.username
  end

  test 'username suffix lookup uses one SELECT and treats underscores literally' do
    %w[ALPHA_BETA alpha_beta_2 alphaXbeta_3].each_with_index do |name, index|
      User.create!(username: name, email: "prefix#{index}@example.test", password: 'TestingPass123')
    end
    statements = []
    callback = ->(*args) { statements << args.last[:sql] if args.last[:sql].match?(/SELECT.*"users"/i) }
    account = OauthAccount.new(github_auth(nickname: 'alpha_beta'))
    result = ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { account.send(:new_username) }
    assert_equal 'alpha_beta_3', result
    assert_equal 1, statements.length
  end
end
