class AllowGithubOauthIdentities < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :oauth_identities, name: 'oauth_identities_allowed_provider'
    add_check_constraint :oauth_identities, "provider IN ('google_oauth2', 'facebook', 'github')", name: 'oauth_identities_allowed_provider'
  end

  def down
    remove_check_constraint :oauth_identities, name: 'oauth_identities_allowed_provider'
    add_check_constraint :oauth_identities, "provider IN ('google_oauth2', 'facebook')", name: 'oauth_identities_allowed_provider'
  end
end
