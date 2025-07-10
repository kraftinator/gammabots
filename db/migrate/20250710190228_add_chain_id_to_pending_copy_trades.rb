class AddChainIdToPendingCopyTrades < ActiveRecord::Migration[7.2]
 def change
   add_reference :pending_copy_trades, :chain, null: false, foreign_key: true, index: true
 end
end
