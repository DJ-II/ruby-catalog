require 'test_helper'

class ExpandedSearchTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(username: 'searchowner', email: 'searchowner@example.test', password: 'TestingPass123')
    category = Category.find_or_create_by!(name: 'Equipment')
    @inventory = Inventory.create!(title: 'Warehouse', category: category, creator: @owner)
    @other = Inventory.create!(title: 'Other storage', category: category, creator: @owner)
    @inventory.inventory_fields.find_by!(kind: 'number', slot: 1).update!(active: true, title: 'Acquisition', description: 'Procurement')
    @inventory.inventory_fields.find_by!(kind: 'link', slot: 1).update!(active: true, title: 'Website')
    @inventory.inventory_fields.find_by!(kind: 'bool', slot: 1).update!(active: true, title: 'Available')
    @inventory.tags << Tag.create!(name: 'specialhardware')
    @inventory.inventory_comments.create!(user: @owner, body: 'Maintenance scheduled')
    @item = @inventory.items.create!(custom_id: 'INV-100', sequence_number: 1, number1: 98765, number2: 123.45, link1: 'https://example.test/manual.pdf', bool1: true)
    @other_item = @other.items.create!(custom_id: 'INV-200', sequence_number: 1, number1: 98765)
  end

  test 'numeric values links and boolean fields are searchable' do
    ['98765', '123.45', 'example.test', 'true'].each do |term|
      assert_includes Item.search_text(term), @item
    end
  end

  test 'tags field definitions and discussions locate their inventory' do
    %w[specialhardware Acquisition Procurement Maintenance].each do |term|
      get search_path(q: term)
      assert_response :success
      assert_select "a[href='#{inventory_path(@inventory)}']", text: @inventory.title
    end
  end

  test 'tag plus item query does not require an inventory text match' do
    get search_path(q: '98765', tag: 'specialhardware')
    assert_response :success
    assert_select "a[href='#{inventory_item_path(@inventory, @item)}']", count: 1
    assert_select "a[href='#{inventory_item_path(@other, @other_item)}']", count: 0
  end
end
