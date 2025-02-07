class AddStrategyIdToBots < ActiveRecord::Migration[7.2]
  def change
    add_reference :bots, :strategy, foreign_key: true
  end
end
