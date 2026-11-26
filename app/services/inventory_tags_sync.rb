class InventoryTagsSync
  MAX_TAGS = 12
  MAX_LENGTH = 40

  def self.parse(value)
    names = value.to_s.split(',').map { |name| name.strip.downcase }.reject(&:blank?).uniq
    raise ArgumentError, I18n.t('tags.invalid') if names.length > MAX_TAGS || names.any? { |name| name.length > MAX_LENGTH || name.match?(/[\x00-\x1f\x7f]/) }
    names
  end

  def self.replace!(inventory, names)
    now = Time.current
    if names.any?
      Tag.insert_all(
        names.map { |name| { name: name, created_at: now, updated_at: now } },
        unique_by: :idx_tags_name
      )
    end
    ids = Tag.where(name: names).pluck(:id)
    inventory.inventory_tags.delete_all
    if ids.any?
      InventoryTag.insert_all!(
        ids.map { |tag_id| { inventory_id: inventory.id, tag_id: tag_id, created_at: now, updated_at: now } }
      )
    end
  end
end
