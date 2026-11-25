require 'test_helper'
require 'csv'

class InventoryItemsExportTest < ActiveSupport::TestCase
  setup do
    category = Category.create!(name: "Books #{SecureRandom.hex(5)}")
    suffix = SecureRandom.hex(5)
    creator = User.create!(username: "biblio_#{suffix}", email: "biblio_#{suffix}@example.test", password: 'TestingPass123')
    @inventory = Inventory.create!(title: 'Library records', category: category, creator: creator)
    @field = @inventory.inventory_fields.find_by!(kind: 'string', slot: 1)
    @field.update!(title: 'Person name', active: true)
    @inventory.items.create!(sequence_number: 1, custom_id: 'INV-000001', creator: creator, string1: 'Mary')
    @inventory.items.create!(sequence_number: 2, custom_id: 'INV-000002', creator: creator, string1: 'John')
  end

  test 'renaming a custom field changes export header without changing existing answers' do
    @field.update!(title: 'Address')
    csv = InventoryItemsExport.new(@inventory).to_csv
    rows = CSV.parse(csv.delete_prefix("\uFEFF"))
    assert_equal 'Address', rows[0][1]
    assert_equal ['Mary', 'John'], rows.drop(1).map { |row| row[1] }
    assert_equal ['Mary', 'John'], @inventory.items.order(:sequence_number).pluck(:string1)
  end

  test 'csv formula injection protection applies to headers and string values' do
    @field.update!(title: '=SUM(1,2)')
    @inventory.items.first.update!(string1: " \t@danger")
    csv = InventoryItemsExport.new(@inventory).to_csv
    rows = CSV.parse(csv.delete_prefix("\uFEFF"))
    assert_equal "'=SUM(1,2)", rows.first[1]
    assert rows.drop(1).any? { |row| row[1] == "' \t@danger" }
  end
end
