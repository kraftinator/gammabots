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

ActiveRecord::Schema[7.2].define(version: 2025_01_24_214418) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "chains", force: :cascade do |t|
    t.string "name", null: false
    t.string "native_chain_id", null: false
    t.string "rpc_url"
    t.string "explorer_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_chains_on_name", unique: true
    t.index ["native_chain_id"], name: "index_chains_on_native_chain_id", unique: true
  end

  create_table "tokens", force: :cascade do |t|
    t.bigint "chain_id", null: false
    t.string "symbol", null: false
    t.string "name", null: false
    t.string "contract_address", null: false
    t.integer "decimals", default: 18, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chain_id", "contract_address"], name: "index_tokens_on_chain_id_and_contract_address", unique: true
    t.index ["chain_id", "symbol"], name: "index_tokens_on_chain_id_and_symbol", unique: true
    t.index ["chain_id"], name: "index_tokens_on_chain_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "farcaster_id", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["farcaster_id"], name: "index_users_on_farcaster_id", unique: true
  end

  add_foreign_key "tokens", "chains"
end
