class UsersController < ApplicationController
  SORT_ORDERS = {
    'newest' => 'inventories.created_at DESC, inventories.id DESC',
    'title' => 'LOWER(inventories.title) ASC, inventories.id ASC',
    'popular' => 'inventories.items_count DESC, inventories.id DESC'
  }.freeze

  def show
    @user = User.find(params[:id])
    @can_manage_profile = current_user.present? && (current_user.id == @user.id || current_user.admin?)

    @owned_sort = valid_sort(params[:owned_sort])
    @writable_sort = valid_sort(params[:writable_sort])
    @owned_filter = params[:owned_filter].to_s.strip.first(100)
    @writable_filter = params[:writable_filter].to_s.strip.first(100)

    owned_scope = filter_by_title(@user.inventories.with_details, @owned_filter)
    writable_scope = filter_by_title(writable_inventories.with_details, @writable_filter)

    @owned_page = PageSlice.new(owned_scope.order(Arel.sql(SORT_ORDERS.fetch(@owned_sort))),
                                page: params[:owned_page], per_page: 20)
    @writable_page = PageSlice.new(writable_scope.order(Arel.sql(SORT_ORDERS.fetch(@writable_sort))),
                                   page: params[:writable_page], per_page: 20)
    @owned = @owned_page.records
    @writable = @writable_page.records
  end

  private

  def writable_inventories
    scope = Inventory.where.not(creator_id: @user.id)
    return scope.none if @user.blocked?
    return scope if @user.admin?

    granted = InventoryAccess.where(user_id: @user.id).select(:inventory_id)
    scope.where(is_public: true).or(scope.where(id: granted))
  end

  def valid_sort(candidate)
    SORT_ORDERS.key?(candidate) ? candidate : 'newest'
  end

  def filter_by_title(scope, value)
    return scope if value.blank?

    scope.where('inventories.title ILIKE ?', "%#{ActiveRecord::Base.sanitize_sql_like(value)}%")
  end
end
