class AddBotCycleToTrades < ActiveRecord::Migration[7.2]
  def change
    add_reference :trades, :bot_cycle, foreign_key: true, index: true, null: true
  end
end
