class CreateOauthIdentities < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :password_login_enabled, :boolean, null: false, default: true

    create_table :oauth_identities do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :provider, null: false, limit: 32
      t.string :uid, null: false, limit: 255
      t.timestamps
    end

    add_index :oauth_identities, [:provider, :uid], unique: true, name: 'idx_oauth_identities_provider_uid'
    add_index :oauth_identities, [:user_id, :provider], unique: true, name: 'idx_oauth_identities_user_provider'
    add_check_constraint :oauth_identities, "provider IN ('google_oauth2', 'facebook')", name: 'oauth_identities_allowed_provider'
    add_check_constraint :oauth_identities, 'length(uid) > 0', name: 'oauth_identities_uid_present'
  end
end
