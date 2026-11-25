class ItemLikesController < ApplicationController
  before_action :set_item
  before_action :require_login

  def create
    @item.item_likes.create_or_find_by!(user: current_user)
    respond_to_like('likes.added')
  end

  def destroy
    @item.item_likes.find_by(user_id: current_user.id)&.destroy!
    respond_to_like('likes.removed')
  end

  private

  def respond_to_like(message)
    editing = params[:return_to_edit] == '1' && can_write?(@inventory)
    respond_to do |format|
      format.html do
        path = editing ? edit_inventory_item_path(@inventory, @item) : inventory_item_path(@inventory, @item)
        redirect_to path, notice: t(message), status: :see_other
      end
      format.json do
        @likes_count = @item.item_likes.count
        @liked = @item.item_likes.exists?(user_id: current_user.id)
        html = render_to_string(partial: 'items/likes', formats: [:html], locals: { editing: editing })
        render json: { html: html }
      end
    end
  end

  def set_item
    @inventory = Inventory.find(params[:inventory_id])
    @item = @inventory.items.find(params[:item_id])
  end
end
