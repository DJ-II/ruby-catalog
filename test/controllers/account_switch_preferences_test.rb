require 'test_helper'

class AccountSwitchPreferencesTest < ActionDispatch::IntegrationTest
  setup do
    suffix = SecureRandom.hex(5)
    @owner = User.create!(username: "owner_#{suffix}", email: "owner_#{suffix}@example.test", password: 'TestingPass123')
    @admin = User.create!(username: "admin_#{suffix}", email: "admin_#{suffix}@example.test", password: 'TestingPass123', admin: true)
  end

  test 'account switching preserves separate themes and locales and guest preferences' do
    patch account_preferences_path, params: { preferences: { locale: 'en', theme: 'dark' } }
    assert_response :redirect
    login_as(@owner)
    assert_preferences('en', 'light')
    patch account_preferences_path, params: { preferences: { locale: 'pl', theme: 'dark' } }
    assert_response :redirect
    get root_path
    assert_preferences('pl', 'dark')
    delete logout_path
    follow_redirect!
    assert_preferences('en', 'dark')
    login_as(@admin)
    assert_preferences('en', 'light')
    patch account_preferences_path, params: { preferences: { locale: 'en', theme: 'light' } }
    assert_response :redirect
    delete logout_path
    follow_redirect!
    assert_preferences('en', 'dark')
    login_as(@owner)
    assert_preferences('pl', 'dark')
    get account_preferences_path
    assert_select 'option[value=dark][selected]'
    assert_select 'option[value=pl][selected]'
    assert_equal 'dark', @owner.reload.theme
    assert_equal 'light', @admin.reload.theme
  end

  test 'authentication forms bypass turbo to render the correct root attributes' do
    get login_path
    assert_select "form[action='#{login_path}'][data-turbo=false]"
    get signup_path
    assert_select "form[action='#{signup_path}'][data-turbo=false]"
    login_as(@owner)
    assert_select "form[action='#{logout_path}'][data-turbo=false]"
  end

  private

  def login_as(user)
    post login_path, params: { email: user.email, password: 'TestingPass123' }
    assert_redirected_to user_path(user)
    follow_redirect!
  end

  def assert_preferences(locale, theme)
    assert_response :success
    assert_select "html[lang=#{locale}][data-bs-theme=#{theme}]"
    assert_select "body[data-page-locale=#{locale}][data-page-theme=#{theme}]"
  end
end
