class CreateInventoryIdParts < ActiveRecord::Migration[8.1]
  def change
    create_table :inventory_id_parts do |t|
      t.references :inventory, null: false, foreign_key: true
      t.string :kind, null: false, limit: 20
      t.string :pattern, null: false, limit: 200
      t.integer :position, null: false
      t.timestamps
    end
    add_index :inventory_id_parts, [:inventory_id, :position], unique: true
    add_check_constraint :inventory_id_parts,
                         "kind IN ('fixed', 'random20', 'random32', 'random6', 'random9', 'guid', 'datetime', 'sequence')",
                         name: 'inventory_id_parts_kind_valid'
    add_check_constraint :inventory_id_parts, 'position >= 0', name: 'inventory_id_parts_position_nonnegative'
  end
end
