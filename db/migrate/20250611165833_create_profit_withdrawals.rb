class CreateProfitWithdrawals < ActiveRecord::Migration[7.2]
  def change
    create_table :profit_withdrawals do |t|
      t.references :bot,            null: false, foreign_key: true
      t.references :bot_cycle,      null: false, foreign_key: true

      t.decimal    :raw_profit,       precision: 30, scale: 18, null: false
      t.decimal    :profit_share,     precision: 5,  scale: 4,  null: false
      t.decimal    :amount_withdrawn, precision: 30, scale: 18, null: false

      t.timestamps
    end
  end
end
