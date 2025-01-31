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

ActiveRecord::Schema[7.2].define(version: 2025_01_31_195054) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "bots", force: :cascade do |t|
    t.bigint "chain_id", null: false
    t.bigint "user_id", null: false
    t.bigint "token_pair_id", null: false
    t.decimal "initial_buy_amount", precision: 30, scale: 10, default: "0.0", null: false
    t.decimal "base_token_amount", precision: 30, scale: 10, default: "0.0", null: false
    t.decimal "quote_token_amount", precision: 30, scale: 10, default: "0.0", null: false
    t.boolean "active", default: true, null: false
    t.datetime "last_traded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "initial_buy_price", precision: 30, scale: 18
    t.decimal "highest_price_since_buy", precision: 30, scale: 18
    t.decimal "lowest_price_since_buy", precision: 30, scale: 18
    t.decimal "highest_price_since_last_trade", precision: 30, scale: 18
    t.decimal "lowest_price_since_last_trade", precision: 30, scale: 18
    t.index ["chain_id"], name: "index_bots_on_chain_id"
    t.index ["last_traded_at"], name: "index_bots_on_last_traded_at"
    t.index ["token_pair_id"], name: "index_bots_on_token_pair_id"
    t.index ["user_id"], name: "index_bots_on_user_id"
  end

  create_table "chains", force: :cascade do |t|
    t.string "name", null: false
    t.string "native_chain_id", null: false
    t.string "explorer_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_chains_on_name", unique: true
    t.index ["native_chain_id"], name: "index_chains_on_native_chain_id", unique: true
  end

  create_table "token_pairs", force: :cascade do |t|
    t.bigint "chain_id", null: false
    t.bigint "base_token_id", null: false
    t.bigint "quote_token_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "current_price", precision: 30, scale: 18
    t.datetime "price_updated_at"
    t.index ["base_token_id"], name: "index_token_pairs_on_base_token_id"
    t.index ["chain_id", "base_token_id", "quote_token_id"], name: "idx_on_chain_id_base_token_id_quote_token_id_220cdf562c", unique: true
    t.index ["chain_id"], name: "index_token_pairs_on_chain_id"
    t.index ["quote_token_id"], name: "index_token_pairs_on_quote_token_id"
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

  create_table "trades", force: :cascade do |t|
    t.bigint "bot_id", null: false
    t.string "trade_type", null: false
    t.decimal "price", precision: 18, scale: 8
    t.decimal "amount", precision: 18, scale: 8
    t.decimal "total_value", precision: 18, scale: 8
    t.datetime "executed_at", null: false
    t.string "tx_hash"
    t.string "status", default: "completed"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "block_number"
    t.decimal "gas_used", precision: 30
    t.index ["block_number"], name: "index_trades_on_block_number"
    t.index ["bot_id"], name: "index_trades_on_bot_id"
    t.index ["executed_at"], name: "index_trades_on_executed_at"
    t.index ["trade_type"], name: "index_trades_on_trade_type"
    t.index ["tx_hash"], name: "index_trades_on_tx_hash", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "farcaster_id", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["farcaster_id"], name: "index_users_on_farcaster_id", unique: true
  end

  create_table "wallets", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "chain_id", null: false
    t.string "private_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chain_id"], name: "index_wallets_on_chain_id"
    t.index ["user_id", "chain_id"], name: "index_wallets_on_user_id_and_chain_id", unique: true
    t.index ["user_id"], name: "index_wallets_on_user_id"
  end

  add_foreign_key "bots", "chains"
  add_foreign_key "bots", "token_pairs"
  add_foreign_key "bots", "users"
  add_foreign_key "token_pairs", "chains"
  add_foreign_key "token_pairs", "tokens", column: "base_token_id"
  add_foreign_key "token_pairs", "tokens", column: "quote_token_id"
  add_foreign_key "tokens", "chains"
  add_foreign_key "trades", "bots"
  add_foreign_key "wallets", "chains"
  add_foreign_key "wallets", "users"
end
