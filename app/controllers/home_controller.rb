class HomeController < ApplicationController
  def index
    @latest = Inventory.with_details.order(created_at: :desc).limit(12)
    @popular = Inventory.with_details.order(items_count: :desc, created_at: :desc).limit(5)
    @tag_cloud = Tag.joins(:inventories)
                    .select('tags.id, tags.name, COUNT(inventories.id) AS inventories_count')
                    .group('tags.id, tags.name')
                    .order(Arel.sql('COUNT(inventories.id) DESC'), :name)
                    .limit(40)
  end
end
