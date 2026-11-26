require 'test_helper'

class CustomIdFlowTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(username: "id_owner_#{SecureRandom.hex(4)}", email: "id_owner_#{SecureRandom.hex(4)}@test.example", password: 'TestingPass123')
    @writer = User.create!(username: "id_writer_#{SecureRandom.hex(4)}", email: "id_writer_#{SecureRandom.hex(4)}@test.example", password: 'TestingPass123')
    @category = Category.create!(name: "Test ID #{SecureRandom.hex(4)}")
    @inventory = Inventory.create!(title: 'Part numbers', creator: @owner, category: @category)
  end

  test 'creator saves template and new item gets generated ID' do
    sign_in(@owner)
    get edit_inventory_id_parts_path(@inventory)
    assert_response :success
    assert_select '[data-id-builder]'
    patch inventory_id_parts_path(@inventory), params: {
      lock_version: @inventory.reload.lock_version,
      parts: {
        'a' => { kind: 'fixed', pattern: 'PART-', position: 0 },
        'b' => { kind: 'sequence', pattern: 'D7', position: 1 }
      }
    }
    assert_redirected_to edit_inventory_id_parts_path(@inventory)
    post inventory_items_path(@inventory), params: { item: { custom_id: '' } }
    assert_redirected_to inventory_path(@inventory)
    item = @inventory.items.last
    assert_equal 'PART-0000001', item.custom_id
    assert_equal 1, item.sequence_number
  end

  test 'invalid ID is rejected but an allowed manual ID can be used' do
    save_parts('fixed' => { kind: 'fixed', pattern: 'COMP-', position: 0 },
               'seq' => { kind: 'sequence', pattern: 'D3', position: 1 })
    sign_in(@owner)
    post inventory_items_path(@inventory), params: { item: { custom_id: 'WRONG-001' } }
    assert_response :unprocessable_entity
    assert_equal 0, @inventory.items.count
    post inventory_items_path(@inventory), params: { item: { custom_id: 'COMP-018' } }
    assert_redirected_to inventory_path(@inventory)
    assert_equal 'COMP-018', @inventory.items.last.custom_id
  end

  test 'changing template preserves existing ID but enforces new rules when item edited' do
    sign_in(@owner)
    post inventory_items_path(@inventory), params: { item: { custom_id: '' } }
    item = @inventory.items.last
    assert_equal 'INV-000001', item.custom_id
    save_parts('fixed' => { kind: 'fixed', pattern: 'NEW-', position: 0 },
               'seq' => { kind: 'sequence', pattern: 'D3', position: 1 })
    assert_equal 'INV-000001', item.reload.custom_id
    patch inventory_item_path(@inventory, item), params: {
      item: { custom_id: 'INV-000001', lock_version: item.lock_version }
    }
    assert_response :unprocessable_entity
    patch inventory_item_path(@inventory, item), params: {
      item: { custom_id: 'NEW-001', lock_version: item.reload.lock_version }
    }
    assert_redirected_to inventory_path(@inventory)
    assert_equal 'NEW-001', item.reload.custom_id
  end

  test 'writers cannot configure an ID template' do
    sign_in(@writer)
    get edit_inventory_id_parts_path(@inventory)
    assert_redirected_to inventory_path(@inventory)
    patch inventory_id_parts_path(@inventory), params: { lock_version: 0 }
    assert_redirected_to inventory_path(@inventory)
  end

  test 'old optimistic-lock form cannot replace a newer ID template' do
    sign_in(@owner)
    stale_version = @inventory.lock_version
    @inventory.update!(title: 'Updated by another tab')
    patch inventory_id_parts_path(@inventory), params: {
      lock_version: stale_version,
      parts: { 'a' => { kind: 'fixed', pattern: 'BAD-', position: 0 } }
    }
    assert_redirected_to edit_inventory_id_parts_path(@inventory)
    assert_equal 0, @inventory.inventory_id_parts.count
  end

  test 'more than fifteen segments are rejected' do
    sign_in(@owner)
    segments = 16.times.to_h { |i| [i.to_s, { kind: 'fixed', pattern: 'A', position: i }] }
    patch inventory_id_parts_path(@inventory), params: { lock_version: @inventory.lock_version, parts: segments }
    assert_response :unprocessable_entity
    assert_equal 0, @inventory.inventory_id_parts.count
  end

  test 'occupied generated ID is rejected without consuming a sequence and a manual duplicate remains invalid' do
    save_parts('a' => { kind: 'fixed', pattern: 'FIXED', position: 0 })
    post inventory_items_path(@inventory), params: { item: { custom_id: '' } }
    assert_redirected_to inventory_path(@inventory)
    assert_equal 'FIXED', @inventory.items.last.custom_id
    assert_no_difference '@inventory.items.count' do
      post inventory_items_path(@inventory), params: { item: { custom_id: '' } }
      assert_response :unprocessable_entity
      post inventory_items_path(@inventory), params: { item: { custom_id: 'FIXED' } }
      assert_response :unprocessable_entity
    end
    assert_equal 1, @inventory.reload.last_sequence
  end

  private

  def save_parts(parts)
    sign_in(@owner)
    patch inventory_id_parts_path(@inventory), params: { lock_version: @inventory.reload.lock_version, parts: parts }
    assert_redirected_to edit_inventory_id_parts_path(@inventory)
  end

  def sign_in(user)
    post login_path, params: { email: user.email, password: 'TestingPass123' }
    assert_redirected_to user_path(user)
  end
end
