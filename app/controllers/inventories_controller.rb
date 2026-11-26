class InventoriesController < ApplicationController
  before_action :require_login, except: [:index, :show, :statistics]
  before_action :set_inventory, only: [:show, :statistics, :edit, :update, :destroy]
  before_action :authorize_owner, only: [:edit, :update, :destroy]

  def index
    @inventory_page = PageSlice.new(Inventory.with_details.order(created_at: :desc, id: :desc),
                                    page: params[:page], per_page: 25)
    @inventories = @inventory_page.records
  end

  def show
    @inventory.association(:tags).load_target
    @fields = @inventory.inventory_fields.select(&:active?).sort_by(&:position)
    @items_page = PageSlice.new(sorted_items,
                                page: params[:page], per_page: 40)
    @items = @items_page.records
    @can_manage = can_manage?(@inventory)
    @can_write = can_write?(@inventory)
  end

  def statistics
    @statistics = InventoryStatistics.new(@inventory).calculate
  end

  def new
    @inventory = Inventory.new
    load_categories
  end

  def create
    @inventory = Inventory.new(inventory_params.except(:lock_version))
    @inventory.creator = current_user
    @tag_names_input = tag_names_input
    names = parse_tags
    if @inventory.errors.any? || !@inventory.valid?
      load_categories
      return render :new, status: :unprocessable_entity
    end
    Inventory.transaction do
      @inventory.save!
      InventoryTagsSync.replace!(@inventory, names) if names
    end
    redirect_to inventory_path(@inventory), notice: t('flash.created')
  rescue ActiveRecord::RecordInvalid
    load_categories
    render :new, status: :unprocessable_entity
  end

  def edit
    load_categories
  end

  def update
    unless params.dig(:inventory, :lock_version).present?
      raise ActiveRecord::StaleObjectError.new(@inventory, 'update')
    end
    @inventory.assign_attributes(inventory_params)
    @inventory.updated_at = Time.current
    @tag_names_input = tag_names_input
    names = parse_tags
    if @inventory.errors.any? || !@inventory.valid?
      return invalid_update
    end
    Inventory.transaction do
      @inventory.save!
      InventoryTagsSync.replace!(@inventory, names) if names
    end
    respond_to do |format|
      format.html { redirect_to inventory_path(@inventory), notice: t('flash.saved') }
      format.json { render json: { lock_version: @inventory.lock_version, message: t('autosave.saved') } }
    end
  rescue ActiveRecord::RecordInvalid
    invalid_update
  rescue ActiveRecord::StaleObjectError
    respond_to do |format|
      format.html { redirect_to edit_inventory_path(@inventory), alert: t('flash.stale') }
      format.json { render json: { error: t('autosave.conflict') }, status: :conflict }
    end
  end

  def destroy
    @inventory.destroy!
    redirect_to user_path(current_user), notice: t('flash.deleted')
  end

  private

  def sorted_items
    scope = @inventory.items.includes(:creator)
    table = Item.arel_table
    allowed = { 'custom_id' => Arel::Nodes::NamedFunction.new('LOWER', [table[:custom_id]]), 'created_at' => table[:created_at] }
    @fields.select(&:visible_in_table?).each do |field|
      column = table[field.column_name]
      allowed[field.column_name] = %w[string text link].include?(field.kind) ? Arel::Nodes::NamedFunction.new('LOWER', [column]) : column
    end
    @sort = params[:sort].to_s
    @direction = params[:direction] == 'asc' ? 'asc' : 'desc'
    if @sort == 'creator'
      scope = scope.left_joins(:creator)
      column = Arel::Nodes::NamedFunction.new('LOWER', [User.arel_table[:username]])
    else
      column = allowed[@sort]
    end
    unless column
      @sort = 'created_at'
      @direction = 'desc'
      column = table[:created_at]
    end
    scope.reorder(column.public_send(@direction).nulls_last, table[:id].desc)
  end

  def invalid_update
    respond_to do |format|
      format.html do
        load_categories
        render :edit, status: :unprocessable_entity
      end
      format.json { render json: { errors: @inventory.errors.full_messages }, status: :unprocessable_entity }
    end
  end

  def set_inventory
    @inventory = Inventory.with_details.find(params[:id])
  end

  def authorize_owner
    redirect_to inventory_path(@inventory), alert: t('flash.forbidden') unless can_manage?(@inventory)
  end

  def inventory_params
    params.require(:inventory).permit(:title, :description, :category_id, :is_public, :image_url, :lock_version)
  end

  def tag_names_input
    params.require(:inventory)[:tag_names] if params.require(:inventory).key?(:tag_names)
  end

  def parse_tags
    return nil if @tag_names_input.nil?
    InventoryTagsSync.parse(@tag_names_input)
  rescue ArgumentError => error
    @inventory.errors.add(:base, error.message)
    nil
  end

  def load_categories
    @categories = Category.order(:name)
  end

end
