require 'test_helper'

class AuthRateLimitTest < ActiveSupport::TestCase
  setup { freeze_time }

  test 'database counters are isolated by scope and client and expire' do
    2.times { assert_nil AuthRateLimit.consume(scope: 'login', client_ip: '192.0.2.1', limit: 2, period: 1.minute) }
    assert_equal 60, AuthRateLimit.consume(scope: 'login', client_ip: '192.0.2.1', limit: 2, period: 1.minute)
    assert_nil AuthRateLimit.consume(scope: 'login', client_ip: '192.0.2.2', limit: 2, period: 1.minute)
    assert_nil AuthRateLimit.consume(scope: 'signup', client_ip: '192.0.2.1', limit: 2, period: 10.minutes)
    assert_equal 3, AuthRateLimit.count
    assert AuthRateLimit.pluck(:client_key).all? { |key| key.match?(/\A[0-9a-f]{64}\z/) }
    travel 61.seconds
    assert_nil AuthRateLimit.consume(scope: 'login', client_ip: '192.0.2.1', limit: 2, period: 1.minute)
    assert_equal 2, AuthRateLimit.count
  end

  test 'trusted Render header is normalized and ignored outside Render' do
    request = Struct.new(:headers, :remote_ip).new({ 'CF-Connecting-IP' => '2001:0db8:0:0::1' }, '192.0.2.10')
    assert_equal '2001:db8::1', AuthRateLimit.client_ip(request, render: true)
    assert_equal '192.0.2.10', AuthRateLimit.client_ip(request, render: false)
    request.headers['CF-Connecting-IP'] = 'invalid, 192.0.2.11'
    assert_equal '192.0.2.10', AuthRateLimit.client_ip(request, render: true)
    request.headers['CF-Connecting-IP'] = '192.0.2.1/24'
    assert_equal '192.0.2.10', AuthRateLimit.client_ip(request, render: true)
  end
end
