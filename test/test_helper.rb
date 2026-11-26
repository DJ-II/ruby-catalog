ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

module ActiveSupport
  class TestCase
    parallelize(workers: 1)
    fixtures :all
    setup { ApplicationController::AUTH_RATE_LIMIT_STORE.clear }
  end
end
