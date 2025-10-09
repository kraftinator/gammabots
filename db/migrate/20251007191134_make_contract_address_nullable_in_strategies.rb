class MakeContractAddressNullableInStrategies < ActiveRecord::Migration[7.2]
  def change
    change_column_null :strategies, :contract_address, true
  end
end
