class AddCreatorAddressToStrategies < ActiveRecord::Migration[7.2]
  def change
    add_column :strategies, :creator_address, :string
    add_index  :strategies, :creator_address
  end
end
