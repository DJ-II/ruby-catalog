class ItemsController < ApplicationController
  before_action :set_inventory
  before_action :require_login, except: :show
  before_action :authorize_writer, except: :show
  before_action :set_item, only: [:show, :edit, :update, :destroy]

  def show
    @fields = @inventory.inventory_fields.select(&:active?).sort_by(&:position)
    load_likes
  end

  def new
    @item = @inventory.items.new
    load_fields
  end

  def create
    @item = @inventory.items.new(item_params.except(:lock_version))
    @item.creator = current_user
    @inventory.with_lock do
      next_number = @inventory.items.maximum(:sequence_number).to_i + 1
      @inventory.update!(last_sequence: next_number)
      @item.sequence_number = next_number
      @item.custom_id = @inventory.custom_id_format.generate(sequence: next_number, at: Time.current) if @item.custom_id.blank?
      @item.save!
    end
    redirect_to inventory_path(@inventory), notice: t('flash.created')
  rescue CustomIdFormat::InvalidFormat => error
    @item.errors.add(:custom_id, error.message)
    load_fields
    render :new, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid
    load_fields
    render :new, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotUnique
    @item.errors.add(:custom_id, t('flash.duplicate_id'))
    load_fields
    render :new, status: :unprocessable_entity
  end

  def edit
    load_fields
  end

  def update
    if params.dig(:item, :lock_version).blank?
      raise ActiveRecord::StaleObjectError.new(@item, 'update')
    end
    if @item.update(item_params)
      redirect_to inventory_path(@inventory), notice: t('flash.saved')
    else
      load_fields
      render :edit, status: :unprocessable_entity
    end
  rescue ActiveRecord::StaleObjectError
    redirect_to edit_inventory_item_path(@inventory, @item), alert: t('flash.stale')
  rescue ActiveRecord::RecordNotUnique
    @item.errors.add(:custom_id, t('flash.duplicate_id'))
    load_fields
    render :edit, status: :unprocessable_entity
  end

  def destroy
    @item.destroy!
    redirect_to inventory_path(@inventory), notice: t('flash.deleted')
  end

  def bulk_destroy
    ids = Array(params[:item_ids]).filter_map { |value| Integer(value, exception: false) }.select(&:positive?).uniq.first(100)
    if ids.any?
      @inventory.items.where(id: ids).delete_all
      Inventory.reset_counters(@inventory.id, :items)
    end
    redirect_to inventory_path(@inventory), notice: t('flash.deleted')
  end

  private

  def set_inventory
    @inventory = Inventory.find(params[:inventory_id])
  end

  def set_item
    @item = @inventory.items.includes(:creator).find(params[:id])
  end

  def authorize_writer
    redirect_to inventory_path(@inventory), alert: t('flash.forbidden') unless can_write?(@inventory)
  end

  def load_likes
    @likes_count = @item.item_likes.count
    @liked = current_user && @item.item_likes.exists?(user_id: current_user.id)
  end

  def load_fields
    load_likes if @item.persisted?
    @fields = @inventory.inventory_fields.select(&:active?).sort_by(&:position)
    @id_example = @inventory.custom_id_format.generate(sequence: @inventory.items.maximum(:sequence_number).to_i + 1, at: Time.current, sample: true)
  rescue CustomIdFormat::InvalidFormat
    @id_example = nil
  end

  def item_params
    editable = @inventory.inventory_fields.select(&:active?).map(&:column_name)
    params.require(:item).permit(:custom_id, :lock_version, *editable)
  end
end
