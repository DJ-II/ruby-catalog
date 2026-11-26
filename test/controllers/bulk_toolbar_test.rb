require 'test_helper'

class BulkToolbarTest < ActionDispatch::IntegrationTest
  test 'write access enables contextual item actions and anonymous readers cannot see them' do
    user = User.create!(username: 'toolbarowner', email: 'toolbarowner@example.test', password: 'TestingPass123')
    category = Category.find_or_create_by!(name: 'Equipment')
    inventory = Inventory.create!(creator: user, category: category, title: 'Toolbar inventory')
    inventory.items.create!(custom_id: 'INV-001', sequence_number: 1, creator: user)
    get inventory_path(inventory)
    assert_select '[data-bulk-action]', count: 0
    post login_path, params: { email: user.email, password: 'TestingPass123' }
    get inventory_path(inventory)
    assert_select 'form[data-bulk-selection="item_ids[]"]' do
      assert_select '[data-bulk-action]', count: 1
      assert_select '[data-bulk-all]', count: 1
      assert_select '[data-bulk-count]', count: 1
      assert_select 'input[name="item_ids[]"]', count: 1
    end
  end
end
