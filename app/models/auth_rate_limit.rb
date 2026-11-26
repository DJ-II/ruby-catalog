require 'ipaddr'
require 'openssl'

class AuthRateLimit < ApplicationRecord
  COUNTER_UPDATE = Arel.sql(<<~SQL.squish).freeze
    attempts = CASE WHEN auth_rate_limits.expires_at <= EXCLUDED.updated_at THEN 1 ELSE LEAST(auth_rate_limits.attempts + 1, 1000000) END,
    expires_at = CASE WHEN auth_rate_limits.expires_at <= EXCLUDED.updated_at THEN EXCLUDED.expires_at ELSE auth_rate_limits.expires_at END,
    updated_at = GREATEST(auth_rate_limits.updated_at, EXCLUDED.updated_at)
  SQL

  def self.client_ip(request, render: Rails.env.production? && ENV['RENDER'] == 'true')
    address = request.headers['CF-Connecting-IP'].to_s
    return request.remote_ip unless render && address.present? && !address.include?('/')
    IPAddr.new(address).native.to_s
  rescue IPAddr::InvalidAddressError, IPAddr::AddressFamilyError
    request.remote_ip
  end

  def self.consume(scope:, client_ip:, limit:, period:)
    now = Time.current
    client_key = OpenSSL::HMAC.hexdigest('SHA256', Rails.application.secret_key_base, "catalog-auth-rate-limit:#{client_ip}")
    where(expires_at: ..now).delete_all
    result = upsert({ scope: scope, client_key: client_key, attempts: 1, expires_at: now + period, updated_at: now }, unique_by: :index_auth_rate_limits_on_scope_and_client_key, on_duplicate: COUNTER_UPDATE, returning: %w[attempts expires_at], record_timestamps: false).first
    return if result.fetch('attempts').to_i <= limit
    expires_at = type_for_attribute('expires_at').deserialize(result.fetch('expires_at'))
    [(expires_at - now).ceil, 1].max
  end
end
