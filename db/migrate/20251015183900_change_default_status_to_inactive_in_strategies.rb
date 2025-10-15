class ChangeDefaultStatusToInactiveInStrategies < ActiveRecord::Migration[7.2]
  def change
    change_column_default :strategies, :status, from: "active", to: "inactive"
  end
end
