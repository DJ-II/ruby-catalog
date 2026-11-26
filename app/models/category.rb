class Category < ApplicationRecord
  has_many :inventories, dependent: :restrict_with_error
  validates :name, presence: true, uniqueness: true

  def localized_name
    key = name.to_s.downcase
    return name unless %w[equipment furniture book books document documents other].include?(key)
    I18n.t("categories.#{key}", default: name)
  end
end
