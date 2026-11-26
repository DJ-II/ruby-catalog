# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_26_000300) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "auth_rate_limits", force: :cascade do |t|
    t.string "scope", limit: 16, null: false
    t.string "client_key", limit: 64, null: false
    t.integer "attempts", null: false
    t.datetime "expires_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_auth_rate_limits_on_expires_at"
    t.index ["scope", "client_key"], name: "index_auth_rate_limits_on_scope_and_client_key", unique: true
    t.check_constraint "attempts > 0", name: "auth_rate_limits_positive_attempts"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_categories_on_name", unique: true
  end

  create_table "inventories", force: :cascade do |t|
    t.bigint "creator_id", null: false
    t.bigint "category_id", null: false
    t.string "title", null: false
    t.text "description"
    t.string "image_url", limit: 2048
    t.boolean "is_public", default: false, null: false
    t.bigint "items_count", default: 0, null: false
    t.bigint "last_sequence", default: 0, null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "to_tsvector('simple'::regconfig, (((COALESCE(title, ''::character varying))::text || ' '::text) || COALESCE(description, ''::text)))", name: "idx_inventories_search", using: :gin
    t.index ["category_id"], name: "index_inventories_on_category_id"
    t.index ["created_at", "id"], name: "index_inventories_on_created_at_and_id"
    t.index ["creator_id"], name: "index_inventories_on_creator_id"
    t.index ["items_count"], name: "index_inventories_on_items_count"
  end

  create_table "inventory_accesses", force: :cascade do |t|
    t.bigint "inventory_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["inventory_id", "user_id"], name: "index_inventory_accesses_on_inventory_id_and_user_id", unique: true
    t.index ["inventory_id"], name: "index_inventory_accesses_on_inventory_id"
    t.index ["user_id"], name: "index_inventory_accesses_on_user_id"
  end

  create_table "inventory_comments", force: :cascade do |t|
    t.bigint "inventory_id", null: false
    t.bigint "user_id"
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "to_tsvector('simple'::regconfig, body)", name: "idx_comments_search", using: :gin
    t.index ["inventory_id", "id"], name: "index_inventory_comments_on_inventory_id_and_id"
    t.index ["inventory_id"], name: "index_inventory_comments_on_inventory_id"
    t.index ["user_id"], name: "index_inventory_comments_on_user_id"
    t.check_constraint "length(btrim(body)) >= 1 AND length(btrim(body)) <= 4000", name: "inventory_comments_body_length"
  end

  create_table "inventory_fields", force: :cascade do |t|
    t.bigint "inventory_id", null: false
    t.string "kind", null: false
    t.integer "slot", null: false
    t.string "title", default: "", null: false
    t.text "description"
    t.boolean "active", default: false, null: false
    t.boolean "visible_in_table", default: false, null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "to_tsvector('simple'::regconfig, (((COALESCE(title, ''::character varying))::text || ' '::text) || COALESCE(description, ''::text)))", name: "idx_active_fields_search", where: "active", using: :gin
    t.index ["inventory_id", "kind", "slot"], name: "idx_inventory_fields_slot", unique: true
    t.index ["inventory_id"], name: "index_inventory_fields_on_inventory_id"
    t.check_constraint "NOT active OR length(btrim(title::text)) > 0", name: "inventory_fields_active_title_required"
    t.check_constraint "kind::text = ANY (ARRAY['string'::character varying::text, 'text'::character varying::text, 'number'::character varying::text, 'link'::character varying::text, 'bool'::character varying::text])", name: "inventory_fields_kind_valid"
    t.check_constraint "slot >= 1 AND slot <= 3", name: "inventory_fields_slot_valid"
  end

  create_table "inventory_id_parts", force: :cascade do |t|
    t.bigint "inventory_id", null: false
    t.string "kind", limit: 20, null: false
    t.string "pattern", limit: 200, null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["inventory_id", "position"], name: "index_inventory_id_parts_on_inventory_id_and_position", unique: true
    t.index ["inventory_id"], name: "index_inventory_id_parts_on_inventory_id"
    t.check_constraint "\"position\" >= 0", name: "inventory_id_parts_position_nonnegative"
    t.check_constraint "kind::text = ANY (ARRAY['fixed'::character varying::text, 'random20'::character varying::text, 'random32'::character varying::text, 'random6'::character varying::text, 'random9'::character varying::text, 'guid'::character varying::text, 'datetime'::character varying::text, 'sequence'::character varying::text])", name: "inventory_id_parts_kind_valid"
  end

  create_table "inventory_tags", force: :cascade do |t|
    t.bigint "inventory_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["inventory_id", "tag_id"], name: "idx_inventory_tags_unique", unique: true
    t.index ["inventory_id"], name: "index_inventory_tags_on_inventory_id"
    t.index ["tag_id", "inventory_id"], name: "idx_inventory_tags_tag_lookup"
    t.index ["tag_id"], name: "index_inventory_tags_on_tag_id"
  end

  create_table "item_likes", force: :cascade do |t|
    t.bigint "item_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id", "user_id"], name: "idx_item_likes_unique_user", unique: true
    t.index ["item_id"], name: "index_item_likes_on_item_id"
    t.index ["user_id"], name: "index_item_likes_on_user_id"
  end

  create_table "items", force: :cascade do |t|
    t.bigint "inventory_id", null: false
    t.bigint "created_by_id"
    t.string "custom_id", null: false
    t.bigint "sequence_number", null: false
    t.string "string1"
    t.text "text1"
    t.decimal "number1", precision: 15, scale: 3
    t.string "link1", limit: 2048
    t.boolean "bool1"
    t.string "string2"
    t.text "text2"
    t.decimal "number2", precision: 15, scale: 3
    t.string "link2", limit: 2048
    t.boolean "bool2"
    t.string "string3"
    t.text "text3"
    t.decimal "number3", precision: 15, scale: 3
    t.string "link3", limit: 2048
    t.boolean "bool3"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "to_tsvector('simple'::regconfig, (((((((((((((((((((((((((((((((COALESCE(custom_id, ''::character varying))::text || ' '::text) || (COALESCE(string1, ''::character varying))::text) || ' '::text) || (COALESCE(string2, ''::character varying))::text) || ' '::text) || (COALESCE(string3, ''::character varying))::text) || ' '::text) || COALESCE(text1, ''::text)) || ' '::text) || COALESCE(text2, ''::text)) || ' '::text) || COALESCE(text3, ''::text)) || ' '::text) || COALESCE((trim_scale(number1))::text, ''::text)) || ' '::text) || COALESCE((trim_scale(number2))::text, ''::text)) || ' '::text) || COALESCE((trim_scale(number3))::text, ''::text)) || ' '::text) || (COALESCE(link1, ''::character varying))::text) || ' '::text) || (COALESCE(link2, ''::character varying))::text) || ' '::text) || (COALESCE(link3, ''::character varying))::text) || ' '::text) || COALESCE((bool1)::text, ''::text)) || ' '::text) || COALESCE((bool2)::text, ''::text)) || ' '::text) || COALESCE((bool3)::text, ''::text)))", name: "idx_items_search", using: :gin
    t.index ["created_by_id"], name: "index_items_on_created_by_id"
    t.index ["inventory_id", "created_at"], name: "index_items_on_inventory_id_and_created_at"
    t.index ["inventory_id", "custom_id"], name: "index_items_on_inventory_id_and_custom_id", unique: true
    t.index ["inventory_id", "sequence_number"], name: "index_items_on_inventory_id_and_sequence_number", unique: true
    t.index ["inventory_id"], name: "index_items_on_inventory_id"
  end

  create_table "oauth_identities", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "provider", limit: 32, null: false
    t.string "uid", limit: 255, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "uid"], name: "idx_oauth_identities_provider_uid", unique: true
    t.index ["user_id", "provider"], name: "idx_oauth_identities_user_provider", unique: true
    t.index ["user_id"], name: "index_oauth_identities_on_user_id"
    t.check_constraint "length(uid::text) > 0", name: "oauth_identities_uid_present"
    t.check_constraint "provider::text = ANY (ARRAY['google_oauth2'::character varying, 'facebook'::character varying, 'github'::character varying]::text[])", name: "oauth_identities_allowed_provider"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name", limit: 40, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "to_tsvector('simple'::regconfig, (name)::text)", name: "idx_tags_search", using: :gin
    t.index ["name"], name: "idx_tags_name", unique: true
    t.index ["name"], name: "idx_tags_prefix", opclass: :varchar_pattern_ops
    t.check_constraint "char_length(btrim(name::text)) >= 1 AND char_length(btrim(name::text)) <= 40", name: "tags_name_length"
  end

  create_table "users", force: :cascade do |t|
    t.string "username", limit: 50, null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.boolean "admin", default: false, null: false
    t.datetime "blocked_at"
    t.string "locale", default: "en", null: false
    t.string "theme", default: "light", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "password_login_enabled", default: true, null: false
    t.index "lower((email)::text)", name: "index_users_on_lower_email", unique: true
    t.index "lower((username)::text)", name: "index_users_on_lower_username", unique: true
  end

  add_foreign_key "inventories", "categories"
  add_foreign_key "inventories", "users", column: "creator_id"
  add_foreign_key "inventory_accesses", "inventories"
  add_foreign_key "inventory_accesses", "users"
  add_foreign_key "inventory_comments", "inventories"
  add_foreign_key "inventory_comments", "users"
  add_foreign_key "inventory_fields", "inventories"
  add_foreign_key "inventory_id_parts", "inventories"
  add_foreign_key "inventory_tags", "inventories"
  add_foreign_key "inventory_tags", "tags"
  add_foreign_key "item_likes", "items", on_delete: :cascade
  add_foreign_key "item_likes", "users"
  add_foreign_key "items", "inventories"
  add_foreign_key "items", "users", column: "created_by_id"
  add_foreign_key "oauth_identities", "users", on_delete: :cascade
end
