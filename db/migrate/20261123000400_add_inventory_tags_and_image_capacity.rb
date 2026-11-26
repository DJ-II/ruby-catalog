class AddInventoryTagsAndImageCapacity < ActiveRecord::Migration[8.1]
  def change
    change_column :inventories, :image_url, :string, limit: 2048
    create_table :tags do |t|
      t.string :name, null: false, limit: 40
      t.timestamps
    end
    add_index :tags, :name, unique: true, name: 'idx_tags_name'
    add_index :tags, :name, opclass: :varchar_pattern_ops, name: 'idx_tags_prefix'
    add_check_constraint :tags, 'char_length(btrim(name)) BETWEEN 1 AND 40', name: 'tags_name_length'
    create_table :inventory_tags do |t|
      t.references :inventory, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true
      t.timestamps
    end
    add_index :inventory_tags, [:inventory_id, :tag_id], unique: true, name: 'idx_inventory_tags_unique'
    add_index :inventory_tags, [:tag_id, :inventory_id], name: 'idx_inventory_tags_tag_lookup'
  end
end
