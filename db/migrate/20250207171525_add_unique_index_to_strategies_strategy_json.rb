class AddUniqueIndexToStrategiesStrategyJson < ActiveRecord::Migration[7.2]
  def change
    add_index :strategies, :strategy_json, unique: true
  end
end
