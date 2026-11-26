require 'test_helper'

class AuthenticationRateLimitTest < ActionDispatch::IntegrationTest
  setup { freeze_time }

  test 'password login is limited after ten attempts' do
    10.times do
      post login_path, params: { email: 'missing@example.test', password: 'wrong' }
      assert_response :unprocessable_entity
    end
    post login_path, params: { email: 'missing@example.test', password: 'wrong' }
    assert_response 429
    assert_equal '60', response.headers['Retry-After']
    assert_includes response.body, I18n.t('flash.rate_limited', locale: :en)
    get login_path
    assert_response :success
  end

  test 'signup is limited independently after five attempts' do
    5.times do
      post signup_path, params: { user: { username: 'x', email: 'invalid', password: 'x' } }
      assert_response :unprocessable_entity
    end
    assert_no_difference 'User.count' do
      post signup_path, params: { user: { username: 'newmember', email: 'newmember@example.test', password: 'TestingPass123', password_confirmation: 'TestingPass123' } }
    end
    assert_response 429
    assert_equal '600', response.headers['Retry-After']
    post login_path, params: { email: 'missing@example.test', password: 'wrong' }
    assert_response :unprocessable_entity
  end

  test 'correct credentials cannot bypass the limit and work after expiry' do
    user = User.create!(username: 'ratelimituser', email: 'ratelimit@example.test', password: 'TestingPass123')
    10.times do
      post login_path, params: { email: user.email, password: 'wrong' }
      assert_response :unprocessable_entity
    end
    post login_path, params: { email: user.email, password: 'TestingPass123' }
    assert_response 429
    assert_equal '60', response.headers['Retry-After']
    travel 30.seconds
    post login_path, params: { email: user.email, password: 'TestingPass123' }
    assert_response 429
    assert_equal '30', response.headers['Retry-After']
    travel 31.seconds
    post login_path, params: { email: user.email, password: 'TestingPass123' }
    assert_redirected_to user_path(user)
  end
end
