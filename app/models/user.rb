require 'uri'

class User < ApplicationRecord
  SUPPORTED_LOCALES = %w[en pl].freeze
  SUPPORTED_THEMES = %w[light dark].freeze
  has_secure_password
  has_many :oauth_identities, dependent: :destroy

  has_many :inventories, foreign_key: :creator_id, dependent: :destroy, inverse_of: :creator
  has_many :items, foreign_key: :created_by_id, dependent: :nullify, inverse_of: :creator
  has_many :inventory_accesses, dependent: :delete_all
  has_many :inventory_comments, dependent: :delete_all
  has_many :item_likes, dependent: :delete_all
  has_many :writable_inventories, through: :inventory_accesses, source: :inventory

  validates :username, presence: true, length: { in: 3..50 }, format: { with: /\A[\p{L}\p{N}_-]+\z/u }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true
  validates :locale, inclusion: { in: SUPPORTED_LOCALES }
  validates :theme, inclusion: { in: SUPPORTED_THEMES }
  validate :unique_username_and_email
  before_validation :normalize_identity

  def blocked?
    blocked_at.present?
  end

  private

  def normalize_identity
    self.email = email.to_s.strip.downcase
    self.username = username.to_s.strip
  end

  def unique_username_and_email
    errors.add(:email, :taken) if email.present? && User.where('lower(email) = ?', email.downcase).where.not(id: id).exists?
    errors.add(:username, :taken) if username.present? && User.where('lower(username) = ?', username.downcase).where.not(id: id).exists?
  end
end
