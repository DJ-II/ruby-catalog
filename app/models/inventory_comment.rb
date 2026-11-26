class InventoryComment < ApplicationRecord
  belongs_to :inventory
  belongs_to :user, optional: true
  validates :user, presence: true, on: :create

  validates :body, presence: true, length: { maximum: 4000 }
  validate :body_is_not_whitespace

  private

  def body_is_not_whitespace
    errors.add(:body, :blank) if body.present? && body.strip.blank?
  end
end
