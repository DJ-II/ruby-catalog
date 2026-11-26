module Admin
  class UsersController < ApplicationController
    before_action :require_login
    before_action :require_admin
    before_action :set_user, only: [:update, :destroy]

    def index
      scope = User.all
      scope = scope.where(admin: params[:role] == 'admin') if %w[admin member].include?(params[:role])
      scope = scope.where.not(blocked_at: nil) if params[:status] == 'blocked'
      scope = scope.where(blocked_at: nil) if params[:status] == 'active'
      table = User.arel_table
      allowed = { 'username' => Arel::Nodes::NamedFunction.new('LOWER', [table[:username]]), 'email' => Arel::Nodes::NamedFunction.new('LOWER', [table[:email]]), 'role' => table[:admin], 'status' => table[:blocked_at].not_eq(nil) }
      @sort = allowed.key?(params[:sort]) ? params[:sort] : 'username'
      @direction = params[:direction] == 'desc' ? 'desc' : 'asc'
      scope = scope.order(allowed.fetch(@sort).public_send(@direction), table[:id].asc)
      if params[:q].present?
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.first(80))}%"
        scope = scope.where('username ILIKE :pattern OR email ILIKE :pattern', pattern: pattern)
      end
      @users_page = PageSlice.new(scope, page: params[:page], per_page: 30)
      @users = @users_page.records
    end

    def manage
      @user = User.find(params[:user_id])
      if params[:operation] == 'delete'
        return destroy
      end
      apply_change
    end

    def update
      apply_change
    end

    def apply_change
      operation = params[:operation].to_s
      result = @user.with_lock do
        case operation
        when 'block'
          if @user.blocked? then :already_blocked else @user.update!(blocked_at: Time.current); :blocked end
        when 'unblock'
          if !@user.blocked? then :already_active else @user.update!(blocked_at: nil); :unblocked end
        when 'promote'
          if @user.admin? then :already_admin else @user.update!(admin: true); :promoted end
        when 'demote'
          if !@user.admin? then :not_admin else @user.update!(admin: false); :demoted end
        else :invalid
        end
      end
      return redirect_to admin_users_path, alert: t('flash.forbidden') if result == :invalid
      target = @user.id == current_user.id && %i[blocked demoted].include?(result) ? root_path : admin_users_path
      if %i[already_blocked already_active already_admin not_admin].include?(result)
        flash[:info] = t("interface.admin.#{result}")
        redirect_to target
      else
        redirect_to target, notice: t("interface.admin.#{result}")
      end
    end

    def destroy
      own = @user == current_user
      @user.destroy!
      reset_session if own
      redirect_to own ? root_path : admin_users_path, notice: t('flash.deleted')
    end

    private

    def set_user
      @user = User.find(params[:id])
    end
  end
end
