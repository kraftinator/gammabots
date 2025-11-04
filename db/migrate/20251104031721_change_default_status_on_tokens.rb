class ChangeDefaultStatusOnTokens < ActiveRecord::Migration[7.2]
  def up
    change_column_default :tokens, :status, from: "pending_validation", to: "rejected"
  end

  def down
    change_column_default :tokens, :status, from: "rejected", to: "pending_validation"
  end
end
