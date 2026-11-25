require 'test_helper'

class SearchControllerTest < ActionDispatch::IntegrationTest
  test 'search displays query safely and has table results' do
    get search_url(q: 'Laptop')
    assert_response :success
    assert_select 'strong', text: 'Laptop'
    assert_select 'table', minimum: 2
  end
end
