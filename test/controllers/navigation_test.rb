require 'test_helper'

class NavigationTest < ActionDispatch::IntegrationTest
  test 'guest header includes centered brand, global search and explore' do
    get root_path
    assert_response :success
    assert_select 'header .site-brand > span:last-child', text: 'Catalog'
    assert_select "header form.site-search[action='#{search_path}'][method=get]"
    assert_select 'header .site-search input[type=search][name=q]'
    assert_select "header .site-navigation a[href='#{inventories_path}']"
    assert_select "header a[href='#{login_path}']"
    assert_select "header a[href='#{signup_path}']"
    assert_select '.home-banner h1', text: 'Organize everything. Find anything.'
    assert_select '.welcome-panel', count: 0
  end

  test 'polish homepage uses compact banner and localized global search' do
    get root_path(lang: 'pl')
    assert_response :success
    assert_select '.home-banner h1', text: 'Porządkuj wszystko. Znajduj bez trudu.'
    assert_select 'header .site-search input[placeholder=?]', 'Szukaj inwentarzy i przedmiotów'
  end

  test 'signed in header keeps profile in account menu and preserves preference and logout forms' do
    user = User.create!(username: 'ui085owner', email: 'ui085owner@example.test', password: 'TestingPass123', admin: true)
    post login_path, params: { email: user.email, password: 'TestingPass123' }
    get root_path
    assert_response :success
    assert_select "header .account-menu a[href='#{user_path(user)}']", count: 1
    assert_select "header .site-navigation a[href='#{user_path(user)}']", count: 0
    assert_select "header .account-menu a[href='#{admin_users_path}']"
    assert_select "header .account-menu a[href='#{account_preferences_path}']"
    assert_select "header form[action='#{logout_path}'][data-turbo=false]"
    assert_select "header form[action='#{account_preferences_path}'][data-turbo=false]", count: 3
    assert_select "main a[href='#{new_inventory_path}']"
  end
end
