class InventoryField < ApplicationRecord
  KINDS = %w[string text number link bool].freeze
  belongs_to :inventory
  validates :kind, inclusion: { in: KINDS }
  validates :slot, inclusion: { in: 1..3 }, uniqueness: { scope: [:inventory_id, :kind] }
  validates :title, length: { maximum: 100 }

  def column_name
    "#{kind}#{slot}"
  end
end
