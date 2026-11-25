class Tag < ApplicationRecord
  has_many :inventory_tags, dependent: :delete_all
  has_many :inventories, through: :inventory_tags

  validates :name, presence: true, length: { maximum: 40 }, uniqueness: true

  scope :starting_with, ->(prefix) {
    escaped = ActiveRecord::Base.sanitize_sql_like(prefix.to_s.downcase.strip)
    where('tags.name LIKE ?', "#{escaped}%").order(:name)
  }
end
