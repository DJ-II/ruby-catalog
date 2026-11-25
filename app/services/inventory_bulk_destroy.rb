class InventoryBulkDestroy
  def self.call(scope)
    Inventory.transaction do
      ids = scope.lock('FOR UPDATE').pluck(:id)
      if ids.empty?
        0
      else
        InventoryAccess.where(inventory_id: ids).delete_all
        InventoryTag.where(inventory_id: ids).delete_all
        InventoryComment.where(inventory_id: ids).delete_all
        InventoryField.where(inventory_id: ids).delete_all
        InventoryIdPart.where(inventory_id: ids).delete_all
        Item.where(inventory_id: ids).delete_all
        Inventory.where(id: ids).delete_all
      end
    end
  end
end
