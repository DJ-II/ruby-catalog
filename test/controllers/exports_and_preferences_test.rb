require 'test_helper'
require 'csv'

class ExportsAndPreferencesTest < ActionDispatch::IntegrationTest
  setup do
    @category = Category.create!(name: "Exports #{SecureRandom.hex(4)}")
    suffix = SecureRandom.hex(5)
    @owner = User.create!(username: "exporter_#{suffix}", email: "exporter_#{suffix}@example.test", password: 'TestingPass123')
    @inventory = Inventory.create!(title: 'Books / Documents', category: @category, creator: @owner)
    @title = @inventory.inventory_fields.find_by!(kind: 'string', slot: 1)
    @title.update!(title: 'Book Title', active: true, visible_in_table: true)
    @year = @inventory.inventory_fields.find_by!(kind: 'number', slot: 1)
    @year.update!(title: 'Published Year', active: true, visible_in_table: false)
    @item = @inventory.items.create!(creator: @owner, custom_id: 'INV-000001', sequence_number: 1, string1: '=HYPERLINK("https://bad.example")', number1: 2026)
  end

  test 'guest can export private inventories as CSV with active fields and protected values' do
    get export_inventory_path(@inventory, format: :csv)
    assert_response :success
    assert_equal 'text/csv', response.media_type
    assert_match(/attachment/, response.headers.fetch('Content-Disposition'))
    assert_match(/\.csv/, response.headers.fetch('Content-Disposition'))
    text = response.body.force_encoding('UTF-8')
    assert text.start_with?("\uFEFF")
    rows = CSV.parse(text.delete_prefix("\uFEFF"))
    assert_equal ['Inventory number', 'Book Title', 'Published Year', 'Created by', 'Created at (UTC)'], rows.first
    assert_equal "'=HYPERLINK(\"https://bad.example\")", rows.second[1]
    assert_equal '2026', rows.second[2]
    assert_equal @owner.username, rows.second[3]
    assert_equal 2, rows.size
    assert_not_includes rows.first, 'id'
  end

  test 'guest can export inventory as an Excel workbook' do
    get export_inventory_path(@inventory, format: :xlsx)
    assert_response :success
    assert_equal 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', response.media_type
    assert response.body.start_with?("PK"), 'Excel workbook should be a ZIP-based .xlsx'
    assert_match(/\.xlsx/, response.headers.fetch('Content-Disposition'))
  end

  test 'unsupported export format returns 406' do
    get export_inventory_path(@inventory, format: :txt)
    assert_response :not_acceptable
  end

  test 'a signed in user saves locale and theme to the account' do
    sign_in
    patch account_preferences_path, params: { preferences: { locale: 'pl', theme: 'dark' } }
    assert_response :redirect
    assert_equal 'pl', @owner.reload.locale
    assert_equal 'dark', @owner.theme
    get account_preferences_path
    assert_response :success
    assert_select 'html[lang=pl][data-bs-theme=dark]'
    assert_select 'option[value=pl][selected]'
    assert_select 'option[value=dark][selected]'
  end

  test 'saving just a language leaves theme unchanged' do
    @owner.update!(theme: 'dark')
    sign_in
    patch account_preferences_path, params: { preferences: { locale: 'pl' } }
    assert_response :redirect
    assert_equal 'dark', @owner.reload.theme
    assert_equal 'pl', @owner.locale
  end

  test 'invalid preferences are rejected and do not alter the account' do
    sign_in
    patch account_preferences_path, params: { preferences: { locale: 'de', theme: 'dark' } }
    assert_response :unprocessable_entity
    assert_equal 'en', @owner.reload.locale
    assert_equal 'light', @owner.theme
  end

  test 'guests can switch language and theme without a user account' do
    patch account_preferences_path, params: { preferences: { locale: 'pl', theme: 'dark' } }
    assert_response :redirect
    get root_path
    assert_response :success
    assert_select 'html[lang=pl][data-bs-theme=dark]'
    get account_preferences_path
    assert_redirected_to login_path
  end

  test 'signed in user sees exports and preferences links but no per-row edit buttons' do
    sign_in
    get inventory_path(@inventory)
    assert_response :success
    assert_select "a[href='#{export_inventory_path(@inventory, format: :csv)}']"
    assert_select "a[href='#{export_inventory_path(@inventory, format: :xlsx)}']"
    assert_select "a[href='#{account_preferences_path}']"
    assert_select 'tbody tr a.btn', count: 0
  end

  private

  def sign_in
    post login_path, params: { email: @owner.email, password: 'TestingPass123' }
    assert_redirected_to user_path(@owner)
  end
end
