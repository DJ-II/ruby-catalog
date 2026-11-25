class InventoryAccessesController < ApplicationController
  before_action :require_login
  before_action :set_inventory
  before_action :require_owner

  def index
    @accesses = @inventory.inventory_accesses.joins(:user).includes(:user)
    @accesses = case params[:sort]
                when 'email' then @accesses.order('users.email ASC, inventory_accesses.id ASC')
                else @accesses.order('users.username ASC, inventory_accesses.id ASC')
                end
    @accesses_page = PageSlice.new(@accesses, page: params[:page], per_page: 30)
    @accesses = @accesses_page.records
  end

  def suggest
    query = params[:q].to_s.strip.downcase.first(80)
    return render json: [] if query.length < 2
    pattern = "#{ActiveRecord::Base.sanitize_sql_like(query)}%"
    users = User.where(blocked_at: nil).where.not(id: @inventory.creator_id)
      .where('lower(username) LIKE :pattern OR lower(email) LIKE :pattern', pattern: pattern)
      .order(:username).limit(10)
    render json: users.map { |user| { username: user.username, email: user.email } }
  end

  def create
    identifier = params[:identifier].to_s.strip.downcase.first(255)
    user = User.where('lower(email) = :value OR lower(username) = :value', value: identifier).first
    if user && !user.blocked? && user.id != @inventory.creator_id
      @inventory.inventory_accesses.find_or_create_by!(user: user)
      redirect_to inventory_accesses_path(@inventory), notice: t('flash.saved')
    else
      redirect_to inventory_accesses_path(@inventory), alert: t('flash.user_not_found')
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_to inventory_accesses_path(@inventory), notice: t('flash.saved')
  end

  def bulk_destroy
    @inventory.inventory_accesses.where(id: Array(params[:access_ids]).map(&:to_i)).delete_all
    redirect_to inventory_accesses_path(@inventory), notice: t('flash.deleted')
  end

  private

  def set_inventory
    @inventory = Inventory.find(params[:inventory_id])
  end

  def require_owner
    redirect_to inventory_path(@inventory), alert: t('flash.forbidden') unless can_manage?(@inventory)
  end
end
