class InventoryCommentsController < ApplicationController
  before_action :set_inventory
  before_action :require_login, only: :create

  def index
    respond_to do |format|
      format.html do
        load_comments
        @comment ||= InventoryComment.new
      end
      format.json do
        after_id = safe_positive_id(params[:after_id])
        comments = @inventory.inventory_comments.includes(:user)
                             .where('id > ?', after_id)
                             .order(:id).limit(75).to_a
        html = render_to_string(partial: 'inventory_comments/comment', collection: comments,
                                as: :comment, formats: [:html])
        render json: { html: html, last_id: comments.last&.id || after_id,
                       more: comments.length == 75 }
      end
    end
  end

  def create
    @comment = @inventory.inventory_comments.new(comment_params)
    @comment.user = current_user
    if @comment.save
      redirect_to inventory_comments_path(@inventory), notice: t('comments.posted')
    else
      load_comments
      render :index, status: :unprocessable_entity
    end
  end

  private

  def set_inventory
    @inventory = Inventory.with_details.find(params[:inventory_id])
  end

  def comment_params
    params.require(:inventory_comment).permit(:body)
  end

  def safe_positive_id(raw)
    Integer(raw, exception: false).to_i.clamp(0, 9_223_372_036_854_775_807)
  end

  def load_comments
    before_id = safe_positive_id(params[:before_id])
    @history = before_id.positive?
    scope = @inventory.inventory_comments.includes(:user)
    scope = scope.where('id < ?', before_id) if @history
    @comments = scope.order(id: :desc).limit(100).to_a.reverse
    @older_id = @comments.first&.id if @comments.length == 100
    @last_id = @comments.last&.id || 0
  end
end
