class OauthIdentity < ApplicationRecord
  PROVIDERS = %w[google_oauth2 facebook].freeze

  belongs_to :user

  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :uid, presence: true, length: { maximum: 255 }, uniqueness: { scope: :provider }
  validates :provider, uniqueness: { scope: :user_id }
end
