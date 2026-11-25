class Inventory < ApplicationRecord
  belongs_to :creator, class_name: 'User', inverse_of: :inventories
  belongs_to :category
  has_many :items, dependent: :delete_all
  has_many :inventory_comments, dependent: :delete_all
  has_many :inventory_fields, dependent: :delete_all
  has_many :inventory_id_parts, -> { order(:position) }, dependent: :delete_all
  has_many :inventory_accesses, dependent: :delete_all
  has_many :writers, through: :inventory_accesses, source: :user
  has_many :inventory_tags, dependent: :delete_all
  has_many :tags, through: :inventory_tags

  validates :title, presence: true, length: { maximum: 150 }
  validates :description, length: { maximum: 20_000 }
  validates :image_url, length: { maximum: 2048 }
  validate :cloudinary_image_url
  after_create :populate_fields

  scope :with_details, -> { includes(:creator, :category) }
  scope :search_text, ->(term) {
    where("to_tsvector('simple', coalesce(inventories.title, '') || ' ' || coalesce(inventories.description, '')) @@ websearch_to_tsquery('simple', ?)", term)
  }

  def editable_by?(user)
    user.present? && (user.admin? || user.id == creator_id)
  end

  def writable_by?(user)
    return false unless user
    editable_by?(user) || is_public? || inventory_accesses.exists?(user_id: user.id)
  end

  def custom_id_format
    CustomIdFormat.new(inventory_id_parts.to_a)
  end

  def active_fields
    inventory_fields.select(&:active?).sort_by(&:position)
  end

  private

  def cloudinary_image_url
    return if image_url.blank?

    cloud = ENV['CLOUDINARY_CLOUD_NAME'].to_s
    if cloud !~ /\A[a-zA-Z0-9_-]+\z/ || image_url !~ /\Ahttps:\/\/res\.cloudinary\.com\/#{Regexp.escape(cloud)}\/image\/upload\/[^\s]+\z/
      errors.add(:image_url, I18n.t('images.invalid_url'))
    end
  end

  def populate_fields
    now = Time.current
    slots = InventoryField::KINDS.flat_map.with_index do |kind, kind_index|
      (1..3).map do |slot|
        { inventory_id: id, kind: kind, slot: slot, title: '', position: kind_index * 3 + slot, active: false, visible_in_table: false, created_at: now, updated_at: now }
      end
    end
    InventoryField.insert_all!(slots)
  end
end
