require 'test_helper'

class SortingAdminAndPreferencesTest < ActionDispatch::IntegrationTest
  setup do
    suffix = SecureRandom.hex(5)
    @owner = User.create!(username: "owner_#{suffix}", email: "owner_#{suffix}@example.test", password: 'TestingPass123')
    @admin = User.create!(username: "admin_#{suffix}", email: "admin_#{suffix}@example.test", password: 'TestingPass123', admin: true)
    @writer = User.create!(username: "writer_#{suffix}", email: "writer_#{suffix}@example.test", password: 'TestingPass123')
    category = Category.create!(name: "Equipment #{suffix}")
    @inventory = Inventory.create!(title: 'Office equipment', creator: @owner, category: category)
    InventoryAccess.create!(inventory: @inventory, user: @writer)
    @inventory.inventory_fields.find_by!(kind: 'number', slot: 1).update!(active: true, title: 'RAM', visible_in_table: true)
    @first = @inventory.items.create!(creator: @owner, custom_id: 'INV-000001', sequence_number: 1, number1: 100)
    @second = @inventory.items.create!(creator: @writer, custom_id: 'INV-000002', sequence_number: 2, number1: 9)
  end

  test 'item sorting is numeric and supports reversing direction and creator sorting' do
    get inventory_path(@inventory), params: { sort: 'number1', direction: 'asc' }
    assert_response :success
    assert_equal [@second.custom_id, @first.custom_id], css_select('tbody .item-id-cell a').map(&:text)
    get inventory_path(@inventory), params: { sort: 'number1', direction: 'desc' }
    assert_response :success
    assert_equal [@first.custom_id, @second.custom_id], css_select('tbody .item-id-cell a').map(&:text)
    get inventory_path(@inventory), params: { sort: 'creator', direction: 'asc' }
    assert_response :success
    assert_equal [@first.custom_id, @second.custom_id], css_select('tbody .item-id-cell a').map(&:text)
    get inventory_path(@inventory), params: { sort: 'password_digest', direction: 'asc' }
    assert_response :success
    assert_select 'th[aria-sort=descending]', count: 1
  end

  test 'administrator can sort and filter users by status and role' do
    sign_in(@admin)
    @writer.update!(blocked_at: Time.current)
    get admin_users_path, params: { role: 'member', status: 'blocked', sort: 'email', direction: 'desc' }
    assert_response :success
    assert_select 'tbody tr', count: 1
    assert_select 'tbody td', text: @writer.email
    get admin_users_path, params: { sort: 'status' }
    assert_response :success
  end

  test 'redundant administrative actions report no change and keep timestamps' do
    sign_in(@admin)
    original = @owner.updated_at
    patch manage_admin_users_path, params: { user_id: @owner.id, operation: 'demote' }
    assert_redirected_to admin_users_path
    assert_equal 'User is not an administrator.', flash[:info]
    assert_equal original, @owner.reload.updated_at
    patch manage_admin_users_path, params: { user_id: @owner.id, operation: 'unblock' }
    assert_equal 'User is already active.', flash[:info]
    patch manage_admin_users_path, params: { user_id: @owner.id, operation: 'block' }
    assert @owner.reload.blocked?
    blocked_at = @owner.blocked_at
    patch manage_admin_users_path, params: { user_id: @owner.id, operation: 'block' }
    assert_equal 'User is already blocked.', flash[:info]
    assert_equal blocked_at, @owner.reload.blocked_at
  end

  test 'owner writer and admin can like from edit form without changing item version' do
    [@owner, @writer, @admin].each do |user|
      sign_in(user)
      get edit_inventory_item_path(@inventory, @first)
      assert_response :success
      assert_select 'form[data-item-like-form]'
      version = @first.reload.lock_version
      post inventory_item_like_path(@inventory, @first), params: { return_to_edit: '1' }, as: :json
      assert_response :success
      assert ItemLike.exists?(item: @first, user: user)
      assert_includes JSON.parse(response.body).fetch('html'), 'data-like-panel'
      assert_equal version, @first.reload.lock_version
      delete inventory_item_like_path(@inventory, @first), params: { return_to_edit: '1' }, as: :json
      assert_response :success
      assert_not ItemLike.exists?(item: @first, user: user)
      delete logout_path
    end
  end

  test 'preferences forms bypass Turbo and changes redirect with GET' do
    sign_in(@owner)
    get account_preferences_path
    assert_response :success
    assert_select 'form[data-turbo=false]', minimum: 4
    patch account_preferences_path, params: { preferences: { theme: 'dark' } }
    assert_response :see_other
    get account_preferences_path
    assert_select 'html[data-bs-theme=dark]'
  end

  test 'discussion dates are displayed in Warsaw time' do
    comment = @inventory.inventory_comments.create!(user: @owner, body: 'Time test', created_at: Time.utc(2026, 11, 24, 12, 0))
    get inventory_comments_path(@inventory)
    assert_response :success
    assert_select "article[data-comment-id='#{comment.id}'] time[datetime='2026-11-24T13:00:00+01:00']"
  end

  private

  def sign_in(user)
    post login_path, params: { email: user.email, password: 'TestingPass123' }
    assert_redirected_to user_path(user)
  end
end
