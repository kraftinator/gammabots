class AddConfirmedAtToTrades < ActiveRecord::Migration[7.2]
  def change
    add_column :trades, :confirmed_at, :datetime
  end
end
