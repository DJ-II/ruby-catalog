class CreateAuthRateLimits < ActiveRecord::Migration[8.1]
  def change
    create_table :auth_rate_limits do |t|
      t.string :scope, null: false, limit: 16
      t.string :client_key, null: false, limit: 64
      t.integer :attempts, null: false
      t.datetime :expires_at, null: false
      t.datetime :updated_at, null: false
    end
    add_index :auth_rate_limits, [:scope, :client_key], unique: true
    add_index :auth_rate_limits, :expires_at
    add_check_constraint :auth_rate_limits, 'attempts > 0', name: 'auth_rate_limits_positive_attempts'
  end
end
