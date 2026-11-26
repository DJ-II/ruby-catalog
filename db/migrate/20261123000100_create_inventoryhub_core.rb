class CreateInventoryhubCore < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :username, null: false, limit: 50
      t.string :email, null: false
      t.string :password_digest, null: false
      t.boolean :admin, null: false, default: false
      t.datetime :blocked_at
      t.string :locale, null: false, default: 'en'
      t.string :theme, null: false, default: 'light'
      t.timestamps
    end
    add_index :users, 'lower(email)', unique: true, name: 'index_users_on_lower_email'
    add_index :users, 'lower(username)', unique: true, name: 'index_users_on_lower_username'
    create_table :categories do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :categories, :name, unique: true
    create_table :inventories do |t|
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.references :category, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :image_url
      t.boolean :is_public, default: false, null: false
      t.bigint :items_count, default: 0, null: false
      t.bigint :last_sequence, default: 0, null: false
      t.integer :lock_version, default: 0, null: false
      t.timestamps
    end
    add_index :inventories, [:created_at, :id]
    add_index :inventories, :items_count
    add_index :inventories, "to_tsvector('simple', coalesce(title, '') || ' ' || coalesce(description, ''))", using: :gin, name: 'idx_inventories_search'
    create_table :inventory_fields do |t|
      t.references :inventory, null: false, foreign_key: true
      t.string :kind, null: false
      t.integer :slot, null: false
      t.string :title, null: false, default: ''
      t.text :description
      t.boolean :active, default: false, null: false
      t.boolean :visible_in_table, default: false, null: false
      t.integer :position, null: false
      t.timestamps
    end
    add_index :inventory_fields, [:inventory_id, :kind, :slot], unique: true, name: 'idx_inventory_fields_slot'
    add_check_constraint :inventory_fields, "kind IN ('string', 'text', 'number', 'link', 'bool')", name: 'inventory_fields_kind_valid'
    add_check_constraint :inventory_fields, 'slot BETWEEN 1 AND 3', name: 'inventory_fields_slot_valid'
    add_check_constraint :inventory_fields, "NOT active OR length(btrim(title)) > 0", name: 'inventory_fields_active_title_required'
    create_table :inventory_accesses do |t|
      t.references :inventory, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    add_index :inventory_accesses, [:inventory_id, :user_id], unique: true
    create_table :items do |t|
      t.references :inventory, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :custom_id, null: false
      t.bigint :sequence_number, null: false
      3.times do |i|
        n = i + 1
        t.string "string#{n}"
        t.text "text#{n}"
        t.decimal "number#{n}", precision: 15, scale: 3
        t.string "link#{n}", limit: 2048
        t.boolean "bool#{n}"
      end
      t.integer :lock_version, default: 0, null: false
      t.timestamps
    end
    add_index :items, [:inventory_id, :custom_id], unique: true
    add_index :items, [:inventory_id, :sequence_number], unique: true
    add_index :items, [:inventory_id, :created_at]
    add_index :items, "to_tsvector('simple', coalesce(custom_id, '') || ' ' || coalesce(string1, '') || ' ' || coalesce(string2, '') || ' ' || coalesce(string3, '') || ' ' || coalesce(text1, '') || ' ' || coalesce(text2, '') || ' ' || coalesce(text3, ''))", using: :gin, name: 'idx_items_search'
  end
end
