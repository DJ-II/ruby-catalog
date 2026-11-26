class InventoryFieldsController < ApplicationController
  before_action :require_login
  before_action :set_inventory
  before_action :require_owner

  def edit
    load_fields
  end

  def update
    allowed_fields = InventoryField::KINDS.product((1..3).to_a).to_h { |kind, slot| ["#{kind}_#{slot}", %i[title description active visible_in_table position]] }
    incoming = params.require(:fields).permit(allowed_fields).to_h
    existing = @inventory.inventory_fields.order(:position).to_a
    now = Time.current
    rows = existing.map do |field|
      data = incoming.fetch("#{field.kind}_#{field.slot}", {})
      {
        inventory_id: @inventory.id, kind: field.kind, slot: field.slot,
        title: data.fetch('title', '').to_s.strip.first(100),
        description: data.fetch('description', '').to_s.strip.first(1000),
        active: data['active'] == '1',
        visible_in_table: data['active'] == '1' && data['visible_in_table'] == '1',
        position: Integer(data['position'], exception: false) || field.position,
        created_at: field.created_at, updated_at: now
      }
    end
    if rows.any? { |row| row[:active] && row[:title].blank? }
      return respond_to do |format|
        format.html { redirect_to edit_inventory_fields_path(@inventory), alert: t('flash.fields_title_required') }
        format.json { render json: { errors: [t('flash.fields_title_required')] }, status: :unprocessable_entity }
      end
    end
    rows.sort_by! { |row| [row[:position], row[:kind], row[:slot]] }
    rows.each_with_index { |row, index| row[:position] = index + 1 }
    @inventory.with_lock do
      if params[:lock_version].blank? || @inventory.lock_version != Integer(params[:lock_version], exception: false)
        raise ActiveRecord::StaleObjectError.new(@inventory, 'update')
      end
      InventoryField.upsert_all(rows, unique_by: :idx_inventory_fields_slot)
      @inventory.update!(updated_at: Time.current)
    end
    respond_to do |format|
      format.html { redirect_to inventory_path(@inventory), notice: t('flash.saved') }
      format.json { render json: { lock_version: @inventory.lock_version, message: t('autosave.saved') } }
    end
  rescue ActiveRecord::StaleObjectError
    respond_to do |format|
      format.html { redirect_to edit_inventory_fields_path(@inventory), alert: t('flash.stale') }
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

  def load_fields
    @fields = @inventory.inventory_fields.order(:position)
  end
end
