require 'test_helper'

class InventoryFlowTest < ActionDispatch::IntegrationTest
  setup do
    @category = Category.create!(name: "Test equipment #{SecureRandom.hex(4)}")
    @owner = User.create!(username: "owner_#{SecureRandom.hex(4)}", email: "owner_#{SecureRandom.hex(4)}@test.example", password: 'TestingPass123', password_confirmation: 'TestingPass123')
    @writer = User.create!(username: "writer_#{SecureRandom.hex(4)}", email: "writer_#{SecureRandom.hex(4)}@test.example", password: 'TestingPass123', password_confirmation: 'TestingPass123')
    @guest_inventory = Inventory.create!(title: 'Laptop storage', description: 'Test warehouse', category: @category, creator: @owner)
  end

  test 'guests can read inventories but cannot add items' do
    get inventory_path(@guest_inventory)
    assert_response :success
    get new_inventory_item_path(@guest_inventory)
    assert_redirected_to login_path
  end

  test 'owner can edit inventory, add field and add item' do
    sign_in(@owner)
    get edit_inventory_fields_path(@guest_inventory)
    assert_response :success
    field = @guest_inventory.inventory_fields.find_by!(kind: 'string', slot: 1)
    all_fields = @guest_inventory.inventory_fields.order(:position)
    params_fields = all_fields.index_with do |record|
      { 'active' => record == field ? '1' : '0', 'visible_in_table' => record == field ? '1' : '0', 'title' => record == field ? 'Model' : '', 'description' => '' }
    end.transform_keys { |record| "#{record.kind}_#{record.slot}" }
    patch inventory_fields_path(@guest_inventory), params: { lock_version: @guest_inventory.reload.lock_version, fields: params_fields }
    assert_redirected_to inventory_path(@guest_inventory)
    post inventory_items_path(@guest_inventory), params: { item: { string1: 'ThinkPad T14' } }
    assert_redirected_to inventory_path(@guest_inventory)
    item = @guest_inventory.items.last
    assert_equal 'INV-000001', item.custom_id
    assert_equal 'ThinkPad T14', item.string1
    assert_equal 1, @guest_inventory.reload.items_count
    get inventory_path(@guest_inventory)
    assert_select 'th', text: 'Model'
  end

  test 'uninvited user cannot edit restricted inventory' do
    sign_in(@writer)
    get new_inventory_item_path(@guest_inventory)
    assert_redirected_to inventory_path(@guest_inventory)
  end

  test 'public inventory grants authenticated writers item access' do
    @guest_inventory.update!(is_public: true)
    sign_in(@writer)
    get new_inventory_item_path(@guest_inventory)
    assert_response :success
    get edit_inventory_fields_path(@guest_inventory)
    assert_redirected_to inventory_path(@guest_inventory)
  end

  test 'writer in access list can add but not edit fields' do
    @guest_inventory.inventory_accesses.create!(user: @writer)
    sign_in(@writer)
    get new_inventory_item_path(@guest_inventory)
    assert_response :success
    get edit_inventory_fields_path(@guest_inventory)
    assert_redirected_to inventory_path(@guest_inventory)
  end

  test 'database rejects duplicate custom IDs in the same inventory' do
    @guest_inventory.items.create!(creator: @owner, custom_id: 'DUPLICATE', sequence_number: 1)
    assert_raises(ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid) do
      @guest_inventory.items.create!(creator: @owner, custom_id: 'DUPLICATE', sequence_number: 2)
    end
  end

  private

  def sign_in(user)
    post login_path, params: { email: user.email, password: 'TestingPass123' }
    assert_redirected_to user_path(user)
  end
end
