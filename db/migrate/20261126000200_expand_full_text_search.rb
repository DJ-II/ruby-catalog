class ExpandFullTextSearch < ActiveRecord::Migration[8.1]
  def up
    remove_index :items, name: 'idx_items_search'
    add_index :items, "to_tsvector('simple', coalesce(custom_id, '') || ' ' || coalesce(string1, '') || ' ' || coalesce(string2, '') || ' ' || coalesce(string3, '') || ' ' || coalesce(text1, '') || ' ' || coalesce(text2, '') || ' ' || coalesce(text3, '') || ' ' || coalesce(trim_scale(number1)::text, '') || ' ' || coalesce(trim_scale(number2)::text, '') || ' ' || coalesce(trim_scale(number3)::text, '') || ' ' || coalesce(link1, '') || ' ' || coalesce(link2, '') || ' ' || coalesce(link3, '') || ' ' || coalesce(bool1::text, '') || ' ' || coalesce(bool2::text, '') || ' ' || coalesce(bool3::text, ''))", using: :gin, name: 'idx_items_search'
    add_index :tags, "to_tsvector('simple', name)", using: :gin, name: 'idx_tags_search'
    add_index :inventory_fields, "to_tsvector('simple', coalesce(title, '') || ' ' || coalesce(description, ''))", using: :gin, where: 'active', name: 'idx_active_fields_search'
    add_index :inventory_comments, "to_tsvector('simple', body)", using: :gin, name: 'idx_comments_search'
  end

  def down
    remove_index :inventory_comments, name: 'idx_comments_search'
    remove_index :inventory_fields, name: 'idx_active_fields_search'
    remove_index :tags, name: 'idx_tags_search'
    remove_index :items, name: 'idx_items_search'
    add_index :items, "to_tsvector('simple', coalesce(custom_id, '') || ' ' || coalesce(string1, '') || ' ' || coalesce(string2, '') || ' ' || coalesce(string3, '') || ' ' || coalesce(text1, '') || ' ' || coalesce(text2, '') || ' ' || coalesce(text3, ''))", using: :gin, name: 'idx_items_search'
  end
end
