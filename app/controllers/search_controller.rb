class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip.first(120)
    @tag = params[:tag].to_s.downcase.strip.first(40)
    inventories = Inventory.with_details
    inventories = inventories.joins(:tags).where(tags: { name: @tag }) if @tag.present?
    tagged_inventory_ids = inventories.reorder(nil).select(:id) if @tag.present?
    inventories = inventories.search_text(@query) if @query.present?
    @inventories_page = PageSlice.new(inventories.order(created_at: :desc, id: :desc),
                                      page: params[:inventory_page], per_page: 25)
    @inventories = @inventories_page.records
    @show_items = @tag.blank? || @query.present?
    if @show_items
      items = Item.includes(:inventory, :creator)
      items = items.where(inventory_id: tagged_inventory_ids) if @tag.present?
      items = items.search_text(@query) if @query.present?
      @items_page = PageSlice.new(items.order(created_at: :desc, id: :desc),
                                  page: params[:item_page], per_page: 25)
      @items = @items_page.records
    else
      @items = []
    end
  end
end
