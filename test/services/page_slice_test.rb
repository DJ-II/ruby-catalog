require 'test_helper'

class PageSliceTest < ActiveSupport::TestCase
  test 'returns the requested page with one extra record only for next-page detection' do
    scope = User.order(:id)
    suffix = SecureRandom.hex(5)
    6.times do |i|
      User.create!(username: "slice_#{suffix}_#{i}", email: "slice_#{suffix}_#{i}@example.test", password: 'TestingPass123')
    end
    result = PageSlice.new(scope.where('username LIKE ?', "slice_#{suffix}%"), page: 2, per_page: 2)
    assert_equal 2, result.page
    assert_equal 2, result.records.length
    assert result.previous?
    assert result.next?
  end

  test 'invalid page values cannot produce negative offsets' do
    result = PageSlice.new(User.none, page: '-50', per_page: 25)
    assert_equal 1, result.page
    assert_empty result.records
    assert_not result.previous?
    assert_not result.next?
  end
end
