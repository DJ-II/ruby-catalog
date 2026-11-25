class CreateCommentsAndLikes < ActiveRecord::Migration[8.1]
  def change
    create_table :inventory_comments do |t|
      t.references :inventory, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false
      t.timestamps
    end
    add_index :inventory_comments, [:inventory_id, :id]
    add_check_constraint :inventory_comments, 'length(btrim(body)) BETWEEN 1 AND 4000', name: 'inventory_comments_body_length'

    create_table :item_likes do |t|
      t.references :item, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    add_index :item_likes, [:item_id, :user_id], unique: true, name: 'idx_item_likes_unique_user'
  end
end
