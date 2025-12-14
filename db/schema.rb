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

ActiveRecord::Schema[7.2].define(version: 2025_12_14_223604) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "bot_cycles", force: :cascade do |t|
    t.bigint "bot_id", null: false
    t.decimal "initial_buy_amount", precision: 30, scale: 18, default: "0.0", null: false
    t.decimal "base_token_amount", precision: 30, scale: 18, default: "0.0", null: false
    t.decimal "quote_token_amount", precision: 30, scale: 18, default: "0.0", null: false
    t.decimal "initial_buy_price", precision: 30, scale: 18
    t.decimal "highest_price_since_initial_buy", precision: 30, scale: 18
    t.decimal "lowest_price_since_initial_buy", precision: 30, scale: 18
    t.decimal "highest_price_since_last_trade", precision: 30, scale: 18
    t.decimal "lowest_price_since_last_trade", precision: 30, scale: 18
    t.decimal "lowest_price_since_creation", precision: 30, scale: 18
    t.decimal "created_at_price", precision: 30, scale: 18
    t.decimal "lowest_moving_avg_since_creation", precision: 30, scale: 18
    t.decimal "highest_moving_avg_since_initial_buy", precision: 30, scale: 18
    t.decimal "lowest_moving_avg_since_initial_buy", precision: 30, scale: 18
    t.decimal "highest_moving_avg_since_last_trade", precision: 30, scale: 18
    t.decimal "lowest_moving_avg_since_last_trade", precision: 30, scale: 18
    t.datetime "started_at", null: false
    t.datetime "ended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "reset_requested_at"
    t.decimal "highest_price_since_creation", precision: 30, scale: 18
    t.index ["bot_id", "ended_at"], name: "index_bot_cycles_on_bot_id_and_ended_at"
    t.index ["bot_id"], name: "index_bot_cycles_on_bot_id"
    t.index ["reset_requested_at"], name: "index_bot_cycles_on_reset_requested_at"
  end

  create_table "bot_events", force: :cascade do |t|
    t.bigint "bot_id", null: false
    t.string "event_type", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bot_id", "event_type", "created_at"], name: "index_bot_events_on_bot_id_and_event_type_and_created_at"
    t.index ["bot_id"], name: "index_bot_events_on_bot_id"
    t.index ["created_at"], name: "index_bot_events_on_created_at"
  end

  create_table "bot_price_metrics", force: :cascade do |t|
    t.bigint "bot_id", null: false
    t.decimal "price", precision: 30, scale: 18, null: false
    t.jsonb "metrics", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bot_id"], name: "index_bot_price_metrics_on_bot_id"
  end

  create_table "bots", force: :cascade do |t|
    t.bigint "chain_id", null: false
    t.bigint "user_id", null: false
    t.bigint "token_pair_id"
    t.decimal "initial_buy_amount", precision: 30, scale: 18, default: "0.0", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "strategy_id"
    t.integer "moving_avg_minutes", default: 5, null: false
    t.decimal "profit_share", precision: 5, scale: 4, default: "0.5", null: false
    t.decimal "profit_threshold", precision: 5, scale: 4, default: "0.1", null: false
    t.string "bot_type", default: "default", null: false
    t.string "copy_wallet_address"
    t.boolean "catch_metrics", default: false, null: false
    t.string "status", default: "pending_funding", null: false
    t.string "funding_tx_hash"
    t.datetime "funding_confirmed_at"
    t.string "funder_address"
    t.string "weth_wrap_tx_hash"
    t.datetime "weth_wrapped_at"
    t.string "weth_unwrap_tx_hash"
    t.string "weth_unwrap_status"
    t.datetime "weth_unwrapped_at"
    t.string "funds_return_tx_hash"
    t.string "funds_return_status"
    t.datetime "funds_returned_at"
    t.decimal "weth_unwrapped_amount", precision: 30, scale: 18
    t.decimal "funds_returned_amount", precision: 30, scale: 18, default: "0.0", null: false
    t.decimal "funding_expected_amount", precision: 30, scale: 18
    t.integer "max_slippage_bps", default: 200, null: false
    t.datetime "liquidated_at"
    t.datetime "deactivated_at"
    t.index ["bot_type", "copy_wallet_address", "token_pair_id"], name: "index_bots_on_copy_bot_fields"
    t.index ["bot_type"], name: "index_bots_on_bot_type"
    t.index ["chain_id"], name: "index_bots_on_chain_id"
    t.index ["copy_wallet_address"], name: "index_bots_on_copy_wallet_address"
    t.index ["deactivated_at"], name: "index_bots_on_deactivated_at"
    t.index ["funder_address"], name: "index_bots_on_funder_address"
    t.index ["funding_tx_hash"], name: "index_bots_on_funding_tx_hash", unique: true
    t.index ["funds_return_tx_hash"], name: "index_bots_on_funds_return_tx_hash"
    t.index ["max_slippage_bps"], name: "index_bots_on_max_slippage_bps"
    t.index ["status"], name: "index_bots_on_status"
    t.index ["strategy_id"], name: "index_bots_on_strategy_id"
    t.index ["token_pair_id"], name: "index_bots_on_token_pair_id"
    t.index ["user_id"], name: "index_bots_on_user_id"
    t.index ["weth_unwrap_tx_hash"], name: "index_bots_on_weth_unwrap_tx_hash"
    t.index ["weth_wrap_tx_hash"], name: "index_bots_on_weth_wrap_tx_hash", unique: true
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

  create_table "copy_trades", force: :cascade do |t|
    t.string "wallet_address", null: false
    t.string "tx_hash", null: false
    t.bigint "block_number", null: false
    t.bigint "token_pair_id", null: false
    t.decimal "amount_out", precision: 30, scale: 18, null: false
    t.decimal "amount_in", precision: 30, scale: 18
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["block_number"], name: "index_copy_trades_on_block_number"
    t.index ["token_pair_id"], name: "index_copy_trades_on_token_pair_id"
    t.index ["tx_hash"], name: "index_copy_trades_on_tx_hash", unique: true
    t.index ["wallet_address", "created_at"], name: "index_copy_trades_on_wallet_address_and_created_at"
    t.index ["wallet_address"], name: "index_copy_trades_on_wallet_address"
  end

  create_table "dashboard_metrics", force: :cascade do |t|
    t.integer "active_bots", default: 0, null: false
    t.bigint "tvl_cents", default: 0, null: false
    t.bigint "volume_24h_cents", default: 0, null: false
    t.integer "strategies_count", default: 0, null: false
    t.bigint "total_profits_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "trades_executed", default: 0, null: false
    t.index ["created_at"], name: "index_dashboard_metrics_on_created_at"
  end

  create_table "fee_collections", force: :cascade do |t|
    t.bigint "trade_id", null: false
    t.decimal "amount", precision: 30, scale: 18, null: false
    t.string "status", default: "pending", null: false
    t.string "tx_hash"
    t.datetime "collected_at"
    t.string "unwrap_status", default: "pending", null: false
    t.string "unwrap_tx_hash"
    t.datetime "unwrapped_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["trade_id"], name: "index_fee_collections_on_trade_id"
  end

  create_table "fee_recipients", force: :cascade do |t|
    t.bigint "fee_collection_id", null: false
    t.string "recipient_type", null: false
    t.string "recipient_address", null: false
    t.decimal "amount", precision: 30, scale: 18, null: false
    t.string "status", default: "pending", null: false
    t.string "tx_hash"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fee_collection_id"], name: "index_fee_recipients_on_fee_collection_id"
  end

  create_table "pending_copy_trades", force: :cascade do |t|
    t.string "wallet_address", null: false
    t.string "token_address", null: false
    t.decimal "amount_out", precision: 30, scale: 18, null: false
    t.string "tx_hash", null: false
    t.bigint "block_number", null: false
    t.string "status", default: "pending"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "chain_id", null: false
    t.index ["chain_id"], name: "index_pending_copy_trades_on_chain_id"
    t.index ["status", "created_at"], name: "index_pending_copy_trades_on_status_and_created_at"
    t.index ["status"], name: "index_pending_copy_trades_on_status"
    t.index ["token_address"], name: "index_pending_copy_trades_on_token_address"
    t.index ["tx_hash"], name: "index_pending_copy_trades_on_tx_hash", unique: true
  end

  create_table "profit_withdrawals", force: :cascade do |t|
    t.bigint "bot_id", null: false
    t.bigint "bot_cycle_id", null: false
    t.decimal "raw_profit", precision: 30, scale: 18, null: false
    t.decimal "profit_share", precision: 5, scale: 4, null: false
    t.decimal "amount_withdrawn", precision: 30, scale: 18, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "payout_token_id"
    t.decimal "payout_amount", precision: 30, scale: 18
    t.string "convert_status", default: "pending", null: false
    t.string "convert_tx_hash"
    t.datetime "converted_at"
    t.string "transfer_status", default: "pending", null: false
    t.string "transfer_tx_hash"
    t.datetime "transferred_at"
    t.text "error_message"
    t.decimal "gas_used", precision: 30
    t.bigint "block_number"
    t.decimal "transaction_fee_wei", precision: 30
    t.jsonb "route"
    t.index ["bot_cycle_id"], name: "index_profit_withdrawals_on_bot_cycle_id"
    t.index ["bot_id"], name: "index_profit_withdrawals_on_bot_id"
    t.index ["convert_status"], name: "index_profit_withdrawals_on_convert_status"
    t.index ["payout_token_id"], name: "index_profit_withdrawals_on_payout_token_id"
    t.index ["transfer_status"], name: "index_profit_withdrawals_on_transfer_status"
  end

  create_table "strategies", force: :cascade do |t|
    t.bigint "chain_id", null: false
    t.string "contract_address"
    t.string "nft_token_id"
    t.text "strategy_json"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "owner_address"
    t.datetime "owner_refreshed_at"
    t.string "mint_tx_hash"
    t.string "mint_status", default: "pending", null: false
    t.string "status", default: "inactive", null: false
    t.string "creator_address"
    t.index ["chain_id"], name: "index_strategies_on_chain_id"
    t.index ["contract_address", "nft_token_id"], name: "index_strategies_on_contract_address_and_nft_token_id", unique: true
    t.index ["creator_address"], name: "index_strategies_on_creator_address"
    t.index ["mint_tx_hash"], name: "index_strategies_on_mint_tx_hash", unique: true
    t.index ["owner_address"], name: "index_strategies_on_owner_address"
    t.index ["status"], name: "index_strategies_on_status"
    t.index ["strategy_json"], name: "index_strategies_on_strategy_json", unique: true
  end

  create_table "token_approvals", force: :cascade do |t|
    t.bigint "wallet_id", null: false
    t.bigint "token_id", null: false
    t.string "status", default: "pending", null: false
    t.string "tx_hash"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "contract_address"
    t.index ["token_id"], name: "index_token_approvals_on_token_id"
    t.index ["wallet_id", "token_id", "contract_address"], name: "index_token_approvals_on_wallet_token_contract", unique: true
    t.index ["wallet_id"], name: "index_token_approvals_on_wallet_id"
  end

  create_table "token_pair_prices", force: :cascade do |t|
    t.bigint "token_pair_id", null: false
    t.decimal "price", precision: 30, scale: 18, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_pair_id", "created_at"], name: "index_token_pair_prices_on_token_pair_id_and_created_at"
    t.index ["token_pair_id"], name: "index_token_pair_prices_on_token_pair_id"
  end

  create_table "token_pairs", force: :cascade do |t|
    t.bigint "chain_id", null: false
    t.bigint "base_token_id", null: false
    t.bigint "quote_token_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "current_price", precision: 30, scale: 18
    t.datetime "price_updated_at"
    t.string "pool_address"
    t.integer "fee_tier"
    t.datetime "pool_address_updated_at"
    t.decimal "max_base_amount_in", precision: 30, scale: 18
    t.index ["base_token_id"], name: "index_token_pairs_on_base_token_id"
    t.index ["chain_id", "base_token_id", "quote_token_id"], name: "idx_on_chain_id_base_token_id_quote_token_id_220cdf562c", unique: true
    t.index ["chain_id"], name: "index_token_pairs_on_chain_id"
    t.index ["pool_address"], name: "index_token_pairs_on_pool_address"
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
    t.string "status", default: "rejected", null: false
    t.jsonb "validation_payload"
    t.datetime "last_validated_at"
    t.index ["chain_id", "contract_address"], name: "index_tokens_on_chain_id_and_contract_address", unique: true
    t.index ["chain_id", "symbol"], name: "index_tokens_on_chain_id_and_symbol"
    t.index ["chain_id"], name: "index_tokens_on_chain_id"
    t.index ["status"], name: "index_tokens_on_status"
  end

  create_table "trades", force: :cascade do |t|
    t.bigint "bot_id", null: false
    t.string "trade_type", null: false
    t.decimal "price", precision: 30, scale: 18
    t.decimal "amount_out", precision: 30, scale: 18
    t.datetime "executed_at", null: false
    t.string "tx_hash", null: false
    t.string "status", default: "pending"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "block_number"
    t.decimal "gas_used", precision: 30
    t.datetime "confirmed_at"
    t.decimal "amount_in", precision: 30, scale: 18
    t.bigint "bot_cycle_id"
    t.bigint "nonce"
    t.jsonb "metrics", default: {}
    t.decimal "listed_price", precision: 30, scale: 18
    t.decimal "transaction_fee_wei", precision: 30
    t.jsonb "route"
    t.integer "max_slippage_bps"
    t.index ["block_number"], name: "index_trades_on_block_number"
    t.index ["bot_cycle_id"], name: "index_trades_on_bot_cycle_id"
    t.index ["bot_id"], name: "index_trades_on_bot_id"
    t.index ["executed_at"], name: "index_trades_on_executed_at"
    t.index ["nonce"], name: "index_trades_on_nonce"
    t.index ["trade_type"], name: "index_trades_on_trade_type"
    t.index ["tx_hash"], name: "index_trades_on_tx_hash", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "farcaster_id", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "created_by_signature"
    t.string "created_by_wallet"
    t.string "profit_withdrawal_address"
    t.string "farcaster_username"
    t.string "farcaster_avatar_url"
    t.datetime "signup_signed_at"
    t.index ["farcaster_id"], name: "index_users_on_farcaster_id", unique: true
  end

  create_table "wallets", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "chain_id", null: false
    t.string "private_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "address"
    t.string "kind", default: "user", null: false
    t.index ["address"], name: "index_wallets_on_address", unique: true
    t.index ["chain_id"], name: "index_wallets_on_chain_id"
    t.index ["user_id", "chain_id"], name: "index_wallets_on_user_id_and_chain_id", unique: true
    t.index ["user_id"], name: "index_wallets_on_user_id"
  end

  add_foreign_key "bot_cycles", "bots"
  add_foreign_key "bot_events", "bots"
  add_foreign_key "bot_price_metrics", "bots"
  add_foreign_key "bots", "chains"
  add_foreign_key "bots", "strategies"
  add_foreign_key "bots", "token_pairs"
  add_foreign_key "bots", "users"
  add_foreign_key "copy_trades", "token_pairs"
  add_foreign_key "fee_collections", "trades"
  add_foreign_key "fee_recipients", "fee_collections"
  add_foreign_key "pending_copy_trades", "chains"
  add_foreign_key "profit_withdrawals", "bot_cycles"
  add_foreign_key "profit_withdrawals", "bots"
  add_foreign_key "profit_withdrawals", "tokens", column: "payout_token_id"
  add_foreign_key "strategies", "chains"
  add_foreign_key "token_approvals", "tokens"
  add_foreign_key "token_approvals", "wallets"
  add_foreign_key "token_pair_prices", "token_pairs"
  add_foreign_key "token_pairs", "chains"
  add_foreign_key "token_pairs", "tokens", column: "base_token_id"
  add_foreign_key "token_pairs", "tokens", column: "quote_token_id"
  add_foreign_key "tokens", "chains"
  add_foreign_key "trades", "bot_cycles"
  add_foreign_key "trades", "bots"
  add_foreign_key "wallets", "chains"
  add_foreign_key "wallets", "users"
end
