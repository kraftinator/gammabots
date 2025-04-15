class AddMovingAvgMinutesToBots < ActiveRecord::Migration[7.2]
  def change
    add_column :bots, :moving_avg_minutes, :integer, default: 5, null: false
  end
end
