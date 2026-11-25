class UserInventoriesController < ApplicationController
  before_action :require_login

  def bulk_destroy
    user = User.find(params[:user_id])
    unless current_user.admin? || current_user.id == user.id
      return redirect_to user_path(user), alert: t('flash.forbidden')
    end

    ids = Array(params[:inventory_ids]).filter_map { |value| Integer(value, exception: false) }
                                       .select(&:positive?).uniq.first(50)
    InventoryBulkDestroy.call(Inventory.where(creator_id: user.id, id: ids)) if ids.any?
    redirect_to user_path(user), notice: t('flash.deleted')
  end
end
