require 'test_helper'

class HomeControllerTest < ActionDispatch::IntegrationTest
  test 'homepage renders without authentication' do
    get root_url
    assert_response :success
    assert_select 'h1', text: 'Organize everything. Find anything.'
  end

  test 'polish locale is available' do
    get root_url(lang: 'pl')
    assert_response :success
    assert_select 'h1', text: 'Porządkuj wszystko. Znajduj bez trudu.'
  end
end
