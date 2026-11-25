require 'test_helper'

class AdminFlowTest < ActionDispatch::IntegrationTest
  test 'admin may remove own admin access' do
    user = User.create!(username: "admin_#{SecureRandom.hex(4)}", email: "admin_#{SecureRandom.hex(4)}@test.example", password: 'TestingPass123')
    user.update!(admin: true)
    post login_path, params: { email: user.email, password: 'TestingPass123' }
    patch manage_admin_users_path, params: { user_id: user.id, operation: 'demote' }
    assert_not user.reload.admin?
    get admin_users_path
    assert_redirected_to root_path
  end
end
