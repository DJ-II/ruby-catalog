class AllowAnonymousInventoryComments < ActiveRecord::Migration[8.1]
  def up
    change_column_null :inventory_comments, :user_id, true
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Anonymous comments cannot be reassigned to deleted users' if select_value('SELECT 1 FROM inventory_comments WHERE user_id IS NULL LIMIT 1')
    change_column_null :inventory_comments, :user_id, false
  end
end
