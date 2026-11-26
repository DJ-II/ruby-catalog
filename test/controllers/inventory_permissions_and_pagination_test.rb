require 'test_helper'

class InventoryPermissionsAndPaginationTest < ActionDispatch::IntegrationTest
  setup do
    suffix = SecureRandom.hex(5)
    @owner = User.create!(username: "v08_owner_#{suffix}", email: "owner_#{suffix}@example.test", password: 'TestingPass123')
    @writer = User.create!(username: "v08_writer_#{suffix}", email: "writer_#{suffix}@example.test", password: 'TestingPass123')
    @other = User.create!(username: "v08_other_#{suffix}", email: "other_#{suffix}@example.test", password: 'TestingPass123')
    @admin = User.create!(username: "v08_admin_#{suffix}", email: "admin_#{suffix}@example.test", password: 'TestingPass123', admin: true)
    @category = Category.create!(name: "V08 category #{suffix}")
    @inventory = Inventory.create!(title: "V08 owned #{suffix}", creator: @owner, category: @category)
    @other_inventory = Inventory.create!(title: "V08 writable #{suffix}", creator: @other, category: @category)
    InventoryAccess.create!(inventory: @other_inventory, user: @owner)
  end

  test 'guests can read inventories, items and search but cannot edit' do
    item = @inventory.items.create!(creator: @owner, custom_id: 'INV-000001', sequence_number: 1)
    get inventories_path
    assert_response :success
    get inventory_path(@inventory)
    assert_response :success
    get inventory_item_path(@inventory, item)
    assert_response :success
    get search_path(q: 'V08')
    assert_response :success
    get edit_inventory_path(@inventory)
    assert_redirected_to login_path
    post inventory_items_path(@inventory), params: { item: { custom_id: '' } }
    assert_redirected_to login_path
  end

  test 'owner profile has independent filters and sorting for both tables' do
    get user_path(@owner, owned_filter: 'V08 owned', writable_filter: 'not present', owned_sort: 'title', writable_sort: 'popular')
    assert_response :success
    assert_select 'section.table-panel', count: 2
    assert_select 'input[name=owned_filter][value=?]', 'V08 owned'
    assert_select 'input[name=writable_filter][value=?]', 'not present'
    assert_select "a[href='#{inventory_path(@inventory)}']", count: 1
    assert_select "a[href='#{inventory_path(@other_inventory)}']", count: 0
  end

  test 'inventory directory and search provide navigation beyond the first page' do
    now = Time.current
    Inventory.insert_all!(28.times.map do |n|
      { title: "Page test #{n.to_s.rjust(2, '0')}", creator_id: @owner.id,
        category_id: @category.id, created_at: now + n.seconds,
        updated_at: now + n.seconds, is_public: false, lock_version: 0,
        items_count: 0, last_sequence: 0 }
    end)
    get inventories_path
    assert_response :success
    assert_select "a[href='#{inventories_path(page: 2)}']", text: 'Next page'
    get inventories_path(page: 2)
    assert_response :success
    assert_select "a[href='#{inventories_path(page: 1)}']", text: 'Previous page'
    get search_path(q: 'Page test')
    assert_response :success
    assert_select 'a', text: 'Next page'
    get search_path(q: 'Page test', inventory_page: 2)
    assert_response :success
    assert_select 'a', text: 'Previous page'
  end

  test 'bulk delete from owner profile is authorized and removes related records' do
    item = @inventory.items.create!(creator: @owner, custom_id: 'INV-000001', sequence_number: 1)
    ItemLike.create!(item: item, user: @writer)
    sign_in(@writer)
    delete bulk_destroy_user_inventories_path(@owner), params: { inventory_ids: [@inventory.id] }
    assert_redirected_to user_path(@owner)
    assert Inventory.exists?(@inventory.id)
    delete logout_path
    sign_in(@owner)
    delete bulk_destroy_user_inventories_path(@owner), params: { inventory_ids: [@inventory.id] }
    assert_redirected_to user_path(@owner)
    assert_not Inventory.exists?(@inventory.id)
    assert_not Item.exists?(item.id)
    assert_not ItemLike.exists?(item_id: item.id)
    assert Inventory.exists?(@other_inventory.id)
  end

  test 'admin can delete another user inventory from their profile' do
    sign_in(@admin)
    get user_path(@owner)
    assert_response :success
    assert_select "input[name='inventory_ids[]'][value='#{@inventory.id}']"
    delete bulk_destroy_user_inventories_path(@owner), params: { inventory_ids: [@inventory.id] }
    assert_not Inventory.exists?(@inventory.id)
  end

  test 'missing and stale lock versions do not overwrite item edits' do
    item = @inventory.items.create!(creator: @owner, custom_id: 'INV-000001', sequence_number: 1)
    sign_in(@owner)
    patch inventory_item_path(@inventory, item), params: { item: { custom_id: 'INV-000002' } }
    assert_redirected_to edit_inventory_item_path(@inventory, item)
    assert_equal 'INV-000001', item.reload.custom_id
    patch inventory_item_path(@inventory, item), params: { item: { custom_id: 'INV-000002', lock_version: item.lock_version } }
    assert_redirected_to inventory_path(@inventory)
    assert_equal 'INV-000002', item.reload.custom_id
    patch inventory_item_path(@inventory, item), params: { item: { custom_id: 'INV-000003', lock_version: 0 } }
    assert_redirected_to edit_inventory_item_path(@inventory, item)
    assert_equal 'INV-000002', item.reload.custom_id
  end

  test 'missing inventory version is rejected by autosave' do
    sign_in(@owner)
    patch inventory_path(@inventory), params: { inventory: { title: 'Unexpected' } }, as: :json
    assert_response :conflict
    assert_equal @inventory.title, @inventory.reload.title
  end

  test 'changing field titles retains existing typed values' do
    number_field = @inventory.inventory_fields.find_by!(kind: 'number', slot: 1)
    number_field.update!(title: 'Person Age', active: true)
    item = @inventory.items.create!(creator: @owner, custom_id: 'INV-000001', sequence_number: 1, number1: 21)
    number_field.update!(title: 'Finger count')
    assert_equal 21, item.reload.number1
    stats = InventoryStatistics.new(@inventory).calculate
    match = stats.fields.find { |entry| entry[:definition].id == number_field.id }
    assert_equal 'Finger count', match.fetch(:definition).title
    assert_equal 21, match.fetch(:summary).fetch(:average).to_i
  end

  test 'Polish UI includes translated custom ID validation error' do
    sign_in(@owner)
    patch account_preferences_path, params: { preferences: { locale: 'pl' } }
    patch inventory_id_parts_path(@inventory), params: {
      lock_version: @inventory.reload.lock_version,
      parts: { a: { kind: 'sequence', pattern: 'BAD', position: 0 } }
    }, as: :json
    assert_response :unprocessable_entity
    assert_includes response.parsed_body.fetch('errors').join, 'Użyj D'
  end

  private

  def sign_in(user)
    post login_path, params: { email: user.email, password: 'TestingPass123' }
    assert_redirected_to user_path(user)
  end
end
