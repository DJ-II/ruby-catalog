class InventoryExportsController < ApplicationController
  def show
    inventory = Inventory.find(params[:id])
    export = InventoryItemsExport.new(inventory)
    case params[:format]
    when 'csv'
      send_data export.to_csv, filename: filename(inventory, 'csv'), type: 'text/csv; charset=utf-8', disposition: 'attachment'
    when 'xlsx'
      send_data export.to_xlsx, filename: filename(inventory, 'xlsx'), type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', disposition: 'attachment'
    else
      head :not_acceptable
    end
  end

  private

  def filename(inventory, extension)
    "inventory-#{inventory.id}-items.#{extension}"
  end
end
