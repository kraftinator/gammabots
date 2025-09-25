class AddPayoutFieldsToProfitWithdrawals < ActiveRecord::Migration[7.2]
  def change
    change_table :profit_withdrawals do |t|
      # Nullable FK to tokens table. If NULL → payout in ETH
      t.references :payout_token, null: true, foreign_key: { to_table: :tokens }

      # Amount actually delivered in payout_token units (or ETH if payout_token_id is nil)
      t.decimal :payout_amount, precision: 30, scale: 18

      # Conversion (swap/unwrap) step
      t.string   :convert_status, default: "pending", null: false
      t.string   :convert_tx_hash
      t.datetime :converted_at

      # Transfer step
      t.string   :transfer_status, default: "pending", null: false
      t.string   :transfer_tx_hash
      t.datetime :transferred_at

      # Error/debug info
      t.text     :error_message
    end

    add_index :profit_withdrawals, :convert_status
    add_index :profit_withdrawals, :transfer_status
  end
end
