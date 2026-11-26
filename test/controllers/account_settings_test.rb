require 'test_helper'

class AccountSettingsTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: 'settings-member', email: 'settings@example.test', password: 'TestingPass123')
    @owner = User.create!(username: 'settings-owner', email: 'settings-owner@example.test', password: 'TestingPass123')
    @category = Category.create!(name: 'Settings test category')
    @inventory = Inventory.create!(title: 'Shared equipment', creator: @owner, category: @category)
  end

  teardown do
    Rails.application.env_config.delete('omniauth.auth')
    Rails.application.env_config.delete('omniauth.params')
  end

  test 'guest cannot view change or delete account settings' do
    get account_settings_path
    assert_redirected_to login_path
    patch account_settings_path, params: { user: { username: 'changed' } }
    assert_redirected_to login_path
    delete account_settings_path, params: { confirmation: 'DELETE' }
    assert_redirected_to login_path
    assert User.exists?(@user.id)
  end

  test 'username can change without changing role or another account' do
    sign_in
    patch account_settings_path, params: { user: { username: 'new_name', admin: true, email: @owner.email, id: @owner.id } }
    assert_redirected_to account_settings_path
    assert_equal 'new_name', @user.reload.username
    follow_redirect!
    assert_select '.account-menu .account-name', text: 'new_name'
    assert_not @user.admin?
    assert_equal 'settings@example.test', @user.email
    assert_equal 'settings-owner', @owner.reload.username
  end

  test 'invalid and duplicate usernames are rejected' do
    sign_in
    ['x', 'SETTINGS-OWNER'].each do |username|
      patch account_settings_path, params: { user: { username: username } }
      assert_response :unprocessable_entity
      assert_select '.account-menu .account-name', text: 'settings-member'
      assert_select 'input[name="user[username]"]', 1 do |inputs|
        assert_equal username, inputs.first['value']
      end
      assert_equal 'settings-member', @user.reload.username
      assert_not @user.admin?
    end
  end

  test 'deletion requires exact confirmation and correct password' do
    sign_in
    assert_no_difference 'User.count' do
      delete account_settings_path, params: { confirmation: 'delete', current_password: 'TestingPass123' }
      assert_redirected_to account_settings_path
      delete account_settings_path, params: { confirmation: 'DELETE', current_password: 'wrong' }
      assert_redirected_to account_settings_path
    end
  end

  test 'deletion removes owned data but preserves contributions to another inventory' do
    sign_in
    owned = Inventory.create!(title: 'Owned equipment', creator: @user, category: @category)
    owned_item = owned.items.create!(creator: @owner, sequence_number: 1, custom_id: 'INV-000001')
    owned_comment = owned.inventory_comments.create!(user: @owner, body: 'Owned inventory comment')
    owned_item.item_likes.create!(user: @owner)
    shared_item = @inventory.items.create!(creator: @user, sequence_number: 1, custom_id: 'INV-000001')
    comment = @inventory.inventory_comments.create!(user: @user, body: 'Shared contribution')
    shared_item.item_likes.create!(user: @user)
    @inventory.inventory_accesses.create!(user: @user)
    @user.oauth_identities.create!(provider: 'github', uid: 'settings-deletion')
    delete account_settings_path, params: { confirmation: 'DELETE', current_password: 'TestingPass123', user_id: @owner.id }
    assert_redirected_to root_path
    assert_not User.exists?(@user.id)
    assert User.exists?(@owner.id)
    assert_not Inventory.exists?(owned.id)
    assert_not Item.exists?(owned_item.id)
    assert_not InventoryComment.exists?(owned_comment.id)
    assert_nil shared_item.reload.created_by_id
    assert_nil comment.reload.user_id
    assert_equal 0, shared_item.item_likes.count
    assert_not InventoryAccess.exists?(user_id: @user.id)
    assert_not OauthIdentity.exists?(user_id: @user.id)
    get account_settings_path
    assert_redirected_to login_path
    get inventory_comments_path(@inventory)
    assert_response :success
    assert_select '.discussion-post', text: /Deleted user/
    get inventory_comments_path(@inventory, format: :json)
    assert_includes response.parsed_body['html'], 'Deleted user'
  end

  test 'OAuth account must confirm the linked identity before deletion' do
    @user.oauth_identities.create!(provider: 'github', uid: 'settings-github')
    @user.update!(password_login_enabled: false)
    oauth_callback('settings-github', 'login')
    assert_redirected_to user_path(@user)
    delete account_settings_path, params: { confirmation: 'DELETE', current_password: 'TestingPass123' }
    assert User.exists?(@user.id)
    oauth_callback('wrong-account', 'delete_reauth')
    assert_redirected_to account_settings_path
    delete account_settings_path, params: { confirmation: 'DELETE' }
    assert User.exists?(@user.id)
    assert_no_difference 'User.count' do
      oauth_callback('settings-github', 'delete_reauth')
    end
    assert_redirected_to account_settings_path
    delete account_settings_path, params: { confirmation: 'DELETE' }
    assert_redirected_to root_path
    assert_not User.exists?(@user.id)
  end

  test 'OAuth proof expires and cannot be used after logout' do
    @user.oauth_identities.create!(provider: 'github', uid: 'settings-github')
    @user.update!(password_login_enabled: false)
    oauth_callback('settings-github', 'login')
    oauth_callback('settings-github', 'delete_reauth')
    travel 6.minutes do
      delete account_settings_path, params: { confirmation: 'DELETE' }
      assert User.exists?(@user.id)
    end
    oauth_callback('settings-github', 'delete_reauth')
    delete logout_path
    oauth_callback('settings-github', 'login')
    delete account_settings_path, params: { confirmation: 'DELETE' }
    assert User.exists?(@user.id)
  end

  test 'privacy policy is public in both languages' do
    get privacy_path
    assert_response :success
    assert_select 'h1', 'Privacy policy'
    get privacy_path, params: { lang: 'pl' }
    assert_response :success
    assert_select 'h1', 'Polityka prywatności'
  end

  private

  def sign_in
    post login_path, params: { email: @user.email, password: 'TestingPass123' }
    assert_redirected_to user_path(@user)
  end

  def oauth_callback(uid, intent)
    Rails.application.env_config['omniauth.auth'] = { 'provider' => 'github', 'uid' => uid, 'info' => {}, 'extra' => {} }
    Rails.application.env_config['omniauth.params'] = { 'intent' => intent }
    get oauth_callback_path('github')
  end
end
