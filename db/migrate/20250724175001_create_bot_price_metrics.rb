class CreateBotPriceMetrics < ActiveRecord::Migration[7.2]
  def change
    create_table :bot_price_metrics do |t|
      t.references :bot, null: false, foreign_key: true
      t.decimal :price, precision: 30, scale: 18, null: false
      t.jsonb :metrics, null: false, default: {}

      t.timestamps
    end
  end
end
