require 'test_helper'

class TableDisplayRegressionTest < ActionDispatch::IntegrationTest
  setup do
    suffix = SecureRandom.hex(5)
    @owner = User.create!(username: "table_#{suffix}", email: "table_#{suffix}@example.test", password: 'TestingPass123')
    @category = Category.create!(name: "Table test #{suffix}")
    @inventory = Inventory.create!(title: 'Table regression', category: @category, creator: @owner)
    @number = @inventory.inventory_fields.find_by!(kind: 'number', slot: 1)
    @number.update!(active: true, title: 'RAM', visible_in_table: true)
    @serial = @inventory.inventory_fields.find_by!(kind: 'string', slot: 1)
    @serial.update!(active: true, title: 'Serial number', visible_in_table: true)
  end

  test 'integer decimals and fractional decimals are displayed without trailing zeros' do
    @inventory.items.create!(creator: @owner, custom_id: 'INV-000001', sequence_number: 1, number1: 24)
    @inventory.items.create!(creator: @owner, custom_id: 'INV-000002', sequence_number: 2, number1: 12.375)
    get inventory_path(@inventory)
    assert_response :success
    assert_select 'td.item-cell', text: '24'
    assert_select 'td.item-cell', text: '12.375'
    assert_select 'td.item-cell', text: '24.0', count: 0
  end

  test 'long serial values retain the full text and cannot exceed the input limit' do
    serial = 'A' * 255
    item = @inventory.items.create!(creator: @owner, custom_id: 'INV-000001', sequence_number: 1, string1: serial)
    get inventory_path(@inventory)
    assert_response :success
    assert_select 'span.item-cell-preview[title=?]', serial
    assert_equal serial, item.reload.string1
    item.string1 = 'B' * 256
    assert_not item.valid?
    assert item.errors[:string1].any?
  end

  test 'inactive fields cannot be marked visible and retain existing item values' do
    item = @inventory.items.create!(creator: @owner, custom_id: 'INV-000001', sequence_number: 1, string1: 'SERIAL-1')
    post login_path, params: { email: @owner.email, password: 'TestingPass123' }
    assert_redirected_to user_path(@owner)
    fields = @inventory.inventory_fields.index_with do |field|
      { active: field == @serial ? '0' : (field.active? ? '1' : '0'),
        title: field.title, description: field.description, visible_in_table: '1', position: field.position }
    end.transform_keys { |field| "#{field.kind}_#{field.slot}" }
    patch inventory_fields_path(@inventory), params: { lock_version: @inventory.reload.lock_version, fields: fields }
    assert_redirected_to inventory_path(@inventory)
    assert_not @serial.reload.active?
    assert_not @serial.visible_in_table?
    assert_equal 'SERIAL-1', item.reload.string1
    get edit_inventory_fields_path(@inventory)
    assert_response :success
    assert_select 'input[type=checkbox][data-field-visible][disabled]', count: 14
  end
end
