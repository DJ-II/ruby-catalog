class Item < ApplicationRecord
  belongs_to :inventory, counter_cache: true
  has_many :item_likes, dependent: :delete_all
  belongs_to :creator, class_name: 'User', foreign_key: :created_by_id, optional: true, inverse_of: :items

  validates :custom_id, presence: true, length: { maximum: 200 }, uniqueness: { scope: :inventory_id }
  validates :sequence_number, presence: true, uniqueness: { scope: :inventory_id }
  validate :matches_current_custom_id_format

  3.times do |n|
    validates "string#{n + 1}", length: { maximum: 255 }
    validates "link#{n + 1}", length: { maximum: 2048 }
  end

  scope :search_text, ->(term) {
    where("to_tsvector('simple', coalesce(items.custom_id, '') || ' ' || coalesce(items.string1, '') || ' ' || coalesce(items.string2, '') || ' ' || coalesce(items.string3, '') || ' ' || coalesce(items.text1, '') || ' ' || coalesce(items.text2, '') || ' ' || coalesce(items.text3, '')) @@ websearch_to_tsquery('simple', ?)", term)
  }
  private

  def matches_current_custom_id_format
    return if custom_id.blank? || inventory.nil?
    return if inventory.custom_id_format.valid_id?(custom_id)
    errors.add(:custom_id, I18n.t('flash.invalid_id_format'))
  end
end
