require 'test_helper'

class TagsStatisticsImagesTest < ActionDispatch::IntegrationTest
  setup do
    @category = Category.create!(name: "Device test #{SecureRandom.hex(4)}")
    @owner = User.create!(username: "tagowner_#{SecureRandom.hex(4)}", email: "tagowner_#{SecureRandom.hex(4)}@test.example", password: 'TestingPass123', password_confirmation: 'TestingPass123')
    @inventory = Inventory.create!(title: 'Lab storage', category: @category, creator: @owner)
  end

  test 'guest can browse stats, tag cloud and tag-filtered search' do
    tag = Tag.create!(name: 'electronics')
    InventoryTag.create!(inventory: @inventory, tag: tag)
    get root_path
    assert_response :success
    assert_select 'a[href=?]', search_path(tag: 'electronics')
    get search_path(tag: 'electronics')
    assert_response :success
    assert_select 'a[href=?]', inventory_path(@inventory), text: @inventory.title
    get statistics_inventory_path(@inventory)
    assert_response :success
    get tag_suggestions_path(q: 'elec')
    assert_response :success
    assert_equal ['electronics'], response.parsed_body.fetch('tags')
  end

  test 'owner saves tags as relational rows with optimistic locking' do
    sign_in
    version = @inventory.lock_version
    patch inventory_path(@inventory), params: { inventory: { title: 'Lab storage', category_id: @category.id, lock_version: version, tag_names: ' Rails, ruby, RAILS ' } }, as: :json
    assert_response :success
    assert_equal %w[rails ruby], @inventory.reload.tags.order(:name).pluck(:name)
    assert_equal version + 1, @inventory.lock_version
    assert_equal 2, InventoryTag.where(inventory_id: @inventory.id).count
    patch inventory_path(@inventory), params: { inventory: { title: 'Stale update', category_id: @category.id, lock_version: version, tag_names: 'replaced' } }, as: :json
    assert_response :conflict
    assert_equal 'Lab storage', @inventory.reload.title
    assert_equal %w[rails ruby], @inventory.tags.order(:name).pluck(:name)
  end

  test 'invalid tags do not update the inventory' do
    sign_in
    patch inventory_path(@inventory), params: { inventory: { title: 'New title', category_id: @category.id, lock_version: @inventory.lock_version, tag_names: 'x' * 41 } }, as: :json
    assert_response :unprocessable_entity
    assert_equal 'Lab storage', @inventory.reload.title
    assert_equal 0, @inventory.tags.count
  end

  test 'statistics compute numerical and boolean aggregates and common strings' do
    @inventory.inventory_fields.find_by!(kind: 'number', slot: 1).update!(active: true, title: 'Price', visible_in_table: true)
    @inventory.inventory_fields.find_by!(kind: 'string', slot: 1).update!(active: true, title: 'Model')
    @inventory.inventory_fields.find_by!(kind: 'bool', slot: 1).update!(active: true, title: 'Active')
    @inventory.items.create!(custom_id: 'INV-000001', sequence_number: 1, number1: 10, string1: 'ThinkPad', bool1: true, creator: @owner)
    @inventory.items.create!(custom_id: 'INV-000002', sequence_number: 2, number1: 30, string1: 'ThinkPad', bool1: false, creator: @owner)
    report = InventoryStatistics.new(@inventory).calculate
    assert_equal 2, report.total
    price = report.fields.find { |entry| entry[:definition].title == 'Price' }[:summary]
    assert_equal 2, price[:numeric_count]
    assert_equal 20, price[:average].to_i
    assert_equal 10, price[:minimum].to_i
    assert_equal 30, price[:maximum].to_i
    model = report.fields.find { |entry| entry[:definition].title == 'Model' }
    assert_equal [{ value: 'ThinkPad', count: 2 }], model[:common]
    state = report.fields.find { |entry| entry[:definition].title == 'Active' }[:summary]
    assert_equal 1, state[:true_count]
    assert_equal 1, state[:false_count]
  end

  test 'image URL is restricted to configured Cloudinary account' do
    previous = ENV['CLOUDINARY_CLOUD_NAME']
    ENV['CLOUDINARY_CLOUD_NAME'] = 'test-cloud'
    @inventory.image_url = 'https://res.cloudinary.com/test-cloud/image/upload/v123/example.png'
    assert @inventory.valid?
    @inventory.image_url = 'https://other.example.net/image.png'
    assert_not @inventory.valid?
    @inventory.image_url = 'http://res.cloudinary.com/test-cloud/image/upload/v123/example.png'
    assert_not @inventory.valid?
  ensure
    ENV['CLOUDINARY_CLOUD_NAME'] = previous
  end

  private

  def sign_in
    post login_path, params: { email: @owner.email, password: 'TestingPass123' }
    assert_redirected_to user_path(@owner)
  end
end
