class CreateFeeRecipients < ActiveRecord::Migration[7.2]
  def change
    create_table :fee_recipients do |t|
      t.references :fee_collection, null: false, foreign_key: true

      t.string :recipient_type, null: false   # "platform", "strategy_owner", "token_owner"
      t.string :recipient_address, null: false

      t.decimal :amount, precision: 30, scale: 18, null: false

      t.string :status, null: false, default: "pending" # pending, submitted, confirmed, failed
      t.string :tx_hash
      t.datetime :sent_at
      t.datetime :confirmed_at

      t.timestamps
    end
  end
end
