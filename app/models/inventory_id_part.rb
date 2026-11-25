class InventoryIdPart < ApplicationRecord
  belongs_to :inventory

  validates :kind, inclusion: { in: CustomIdFormat::KINDS }
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :pattern, presence: true, length: { maximum: CustomIdFormat::MAX_ID_LENGTH }
  validate :validate_pattern

  private

  def validate_pattern
    CustomIdFormat.validate_part!(kind, pattern)
  rescue CustomIdFormat::InvalidFormat => error
    errors.add(:pattern, error.message)
  end
end
