class InventoryIdPartsController < ApplicationController
  before_action :require_login
  before_action :set_inventory
  before_action :require_owner

  def edit
    load_editor
  end

  def update
    @parts = parse_parts
    format = CustomIdFormat.new(@parts)
    @preview = format.generate(sequence: @inventory.items.maximum(:sequence_number).to_i + 1, sample: true)

    @inventory.with_lock do
      if params[:lock_version].blank? || @inventory.lock_version != Integer(params[:lock_version], exception: false)
        raise ActiveRecord::StaleObjectError.new(@inventory, 'update')
      end

      @inventory.inventory_id_parts.delete_all
      now = Time.current
      rows = @parts.each_with_index.map do |part, position|
        { inventory_id: @inventory.id, kind: part.kind, pattern: part.pattern,
          position: position, created_at: now, updated_at: now }
      end
      InventoryIdPart.insert_all!(rows) if rows.any?
      @inventory.update!(updated_at: Time.current)
    end
    respond_to do |format|
      format.html { redirect_to edit_inventory_id_parts_path(@inventory), notice: t('flash.saved') }
      format.json { render json: { lock_version: @inventory.lock_version, message: t('autosave.saved') } }
    end
  rescue CustomIdFormat::InvalidFormat => error
    respond_to do |format|
      format.html do
        @parts ||= @inventory.inventory_id_parts.to_a
        flash.now[:alert] = error.message
        @preview = nil
        render :edit, status: :unprocessable_entity
      end
      format.json { render json: { errors: [error.message] }, status: :unprocessable_entity }
    end
  rescue ActiveRecord::StaleObjectError
    respond_to do |format|
      format.html { redirect_to edit_inventory_id_parts_path(@inventory), alert: t('flash.stale') }
      format.json { render json: { error: t('autosave.conflict') }, status: :conflict }
    end
  end

  private

  def set_inventory
    @inventory = Inventory.find(params[:inventory_id])
  end

  def require_owner
    redirect_to inventory_path(@inventory), alert: t('flash.forbidden') unless can_manage?(@inventory)
  end

  def load_editor
    @parts = @inventory.inventory_id_parts.to_a
    @preview = @inventory.custom_id_format.generate(sequence: @inventory.items.maximum(:sequence_number).to_i + 1,
                                                   at: Time.current, sample: true)
  end

  def parse_parts
    raw = params[:parts]
    return [] if raw.blank?
    raise CustomIdFormat::InvalidFormat, t('ids.errors.invalid_list') unless raw.is_a?(ActionController::Parameters)
    raise CustomIdFormat::InvalidFormat, t('ids.errors.too_many', count: CustomIdFormat::MAX_PARTS) if raw.keys.size > CustomIdFormat::MAX_PARTS

    raw.keys.map do |key|
      part = raw[key]
      raise CustomIdFormat::InvalidFormat, t('ids.errors.invalid_element') unless part.is_a?(ActionController::Parameters)

      kind = part[:kind].to_s
      pattern = part[:pattern].to_s
      CustomIdFormat.validate_part!(kind, pattern)
      position = Integer(part[:position], exception: false)
      raise CustomIdFormat::InvalidFormat, t('ids.errors.invalid_order') if position.nil? || position.negative?

      InventoryIdPart.new(inventory: @inventory, kind: kind, pattern: pattern, position: position)
    end.sort_by(&:position)
  end
end
