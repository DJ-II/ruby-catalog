require 'test_helper'

class ProfileAccessAndBrandingTest < ActionDispatch::IntegrationTest
  setup do
    suffix = SecureRandom.hex(4)
    @member = User.create!(username: "cat_member_#{suffix}", email: "member_#{suffix}@example.test", password: 'TestingPass123')
    @other = User.create!(username: "cat_other_#{suffix}", email: "other_#{suffix}@example.test", password: 'TestingPass123')
    @category = Category.find_or_create_by!(name: 'Equipment')
    @own = Inventory.create!(creator: @member, category: @category, title: "Owned #{suffix}", is_public: true)
    @public = Inventory.create!(creator: @other, category: @category, title: "Public #{suffix}", is_public: true)
    @granted = Inventory.create!(creator: @other, category: @category, title: "Granted #{suffix}", is_public: false)
    @private = Inventory.create!(creator: @other, category: @category, title: "Private #{suffix}", is_public: false)
    InventoryAccess.create!(inventory: @public, user: @member)
    InventoryAccess.create!(inventory: @granted, user: @member)
  end

  test 'profile shows public and explicitly granted inventories once excluding own and private' do
    get user_path(@member)
    assert_response :success
    assert_select "a[href='#{inventory_path(@own)}']", count: 1
    assert_select "a[href='#{inventory_path(@public)}']", count: 1
    assert_select "a[href='#{inventory_path(@granted)}']", count: 1
    assert_select "a[href='#{inventory_path(@private)}']", count: 0
  end

  test 'administrator writable list includes all other inventories' do
    @member.update!(admin: true)
    get user_path(@member)
    assert_response :success
    assert_select "a[href='#{inventory_path(@private)}']", count: 1
    assert_select "a[href='#{inventory_path(@own)}']", count: 1
  end

  test 'blocked profile has no writable inventories outside its owned list' do
    @member.update!(blocked_at: Time.current)
    get user_path(@member)
    assert_response :success
    assert_select "a[href='#{inventory_path(@public)}']", count: 0
    assert_select "a[href='#{inventory_path(@granted)}']", count: 0
  end

  test 'categories are translated but stored values and inventory titles are preserved' do
    get inventories_path(lang: 'pl')
    assert_response :success
    assert_select 'td', text: 'Sprzęt', minimum: 1
    assert_select "a[href='#{inventory_path(@own)}']", text: @own.title
    assert_equal 'Equipment', @category.reload.name
    get inventory_path(@own, lang: 'pl')
    assert_response :success
    assert_select '.inventory-summary .eyebrow', text: /Sprzęt/
  end

  test 'catalog branding includes full width bands and banner only on homepage' do
    get root_path
    assert_response :success
    assert_select 'title', text: 'Catalog'
    assert_select 'header .catalog-wordmark', text: 'Catalog'
    assert_select 'header .toolbar-band .site-toolbar', count: 1
    assert_select 'body > .home-banner', count: 1
    get inventories_path
    assert_response :success
    assert_select '.home-banner', count: 0
  end
end
