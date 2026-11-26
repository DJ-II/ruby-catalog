require 'test_helper'

class CollaborationFlowTest < ActionDispatch::IntegrationTest
  setup do
    token = SecureRandom.hex(5)
    @owner = User.create!(username: "owner_#{token}", email: "owner_#{token}@test.example", password: 'TestingPass123')
    @member = User.create!(username: "member_#{token}", email: "member_#{token}@test.example", password: 'TestingPass123')
    @category = Category.create!(name: "Collaboration #{token}")
    @inventory = Inventory.create!(title: 'Office equipment', description: 'Inventory', creator: @owner, category: @category)
    @item = @inventory.items.create!(creator: @owner, sequence_number: 1, custom_id: 'INV-000001')
  end

  test 'guest can read discussion but cannot post' do
    get inventory_comments_path(@inventory)
    assert_response :success
    assert_select 'h1', text: 'Inventory discussion'
    post inventory_comments_path(@inventory), params: { inventory_comment: { body: 'Hello' } }
    assert_redirected_to login_path
    assert_equal 0, @inventory.inventory_comments.count
  end

  test 'any authenticated user can post markdown and polling returns only newer comments' do
    sign_in(@member)
    post inventory_comments_path(@inventory), params: { inventory_comment: { body: '**Hello** [link](https://example.org)' } }
    assert_redirected_to inventory_comments_path(@inventory)
    first = @inventory.inventory_comments.last
    post inventory_comments_path(@inventory), params: { inventory_comment: { body: 'Second post' } }
    get inventory_comments_path(@inventory, format: :json), params: { after_id: first.id }
    assert_response :success
    assert_equal @inventory.inventory_comments.last.id, response.parsed_body['last_id']
    assert_includes response.parsed_body['html'], 'Second post'
    assert_not_includes response.parsed_body['html'], '**Hello**'
    assert_not_includes response.parsed_body['html'], '<script'
    get inventory_comments_path(@inventory)
    assert_select '.discussion-markdown strong', text: 'Hello'
    assert_select '.discussion-post', count: 2
  end

  test 'blank and oversized discussion entries are rejected' do
    sign_in(@member)
    post inventory_comments_path(@inventory), params: { inventory_comment: { body: '  ' } }
    assert_response :unprocessable_entity
    post inventory_comments_path(@inventory), params: { inventory_comment: { body: 'A' * 4001 } }
    assert_response :unprocessable_entity
    assert_equal 0, @inventory.inventory_comments.count
  end

  test 'a signed-in user can like a read-only item only once and unlike it' do
    post inventory_item_like_path(@inventory, @item)
    assert_redirected_to login_path
    sign_in(@member)
    2.times do
      post inventory_item_like_path(@inventory, @item)
      assert_redirected_to inventory_item_path(@inventory, @item)
    end
    assert_equal 1, @item.item_likes.count
    get inventory_item_path(@inventory, @item)
    assert_select 'button', text: 'Unlike'
    delete inventory_item_like_path(@inventory, @item)
    assert_redirected_to inventory_item_path(@inventory, @item)
    assert_equal 0, @item.item_likes.count
  end

  test 'unique database index rejects a second like from one user' do
    @item.item_likes.create!(user: @member)
    assert_raises(ActiveRecord::RecordNotUnique) do
      @item.item_likes.create!(user: @member)
    end
  end

  test 'deleting a liked item in bulk removes likes without errors' do
    @item.item_likes.create!(user: @member)
    sign_in(@owner)
    delete bulk_destroy_inventory_items_path(@inventory), params: { item_ids: [@item.id] }
    assert_redirected_to inventory_path(@inventory)
    assert_equal 0, ItemLike.where(item_id: @item.id).count
    assert_equal 0, @inventory.reload.items_count
  end

  test 'autosave returns a newer version and refuses stale settings' do
    sign_in(@owner)
    version = @inventory.lock_version
    patch inventory_path(@inventory), params: { inventory: { title: 'Updated title', lock_version: version } }, as: :json
    assert_response :success
    new_version = response.parsed_body['lock_version']
    assert_operator new_version, :>, version
    assert_equal 'Updated title', @inventory.reload.title
    patch inventory_path(@inventory), params: { inventory: { title: 'Stale overwrite', lock_version: version } }, as: :json
    assert_response :conflict
    assert_equal 'Updated title', @inventory.reload.title
  end

  test 'field and ID editors both return new lock versions' do
    sign_in(@owner)
    fields = @inventory.inventory_fields.order(:position).to_a.index_with do |field|
      { 'active' => field.kind == 'string' && field.slot == 1 ? '1' : '0',
        'visible_in_table' => '0',
        'title' => field.kind == 'string' && field.slot == 1 ? 'Model' : '',
        'description' => '', 'position' => field.position.to_s }
    end.transform_keys { |field| "#{field.kind}_#{field.slot}" }
    patch inventory_fields_path(@inventory), params: { lock_version: @inventory.lock_version, fields: fields }, as: :json
    assert_response :success
    field_version = response.parsed_body['lock_version']
    assert_operator field_version, :>, 0
    assert @inventory.inventory_fields.find_by!(kind: 'string', slot: 1).active?
    patch inventory_id_parts_path(@inventory), params: {
      lock_version: field_version,
      parts: { one: { kind: 'fixed', pattern: 'EQ-', position: 0 }, two: { kind: 'sequence', pattern: 'D3', position: 1 } }
    }, as: :json
    assert_response :success
    assert_operator response.parsed_body['lock_version'], :>, field_version
    assert_equal 2, @inventory.inventory_id_parts.count
    patch inventory_id_parts_path(@inventory), params: {
      lock_version: field_version,
      parts: { one: { kind: 'fixed', pattern: 'BAD-', position: 0 } }
    }, as: :json
    assert_response :conflict
    assert_equal 'EQ-', @inventory.inventory_id_parts.order(:position).first.pattern
  end

  private

  def sign_in(user)
    post login_path, params: { email: user.email, password: 'TestingPass123' }
    assert_redirected_to user_path(user)
  end
end
