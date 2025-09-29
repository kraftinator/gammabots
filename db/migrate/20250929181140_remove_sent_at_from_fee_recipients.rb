class RemoveSentAtFromFeeRecipients < ActiveRecord::Migration[7.2]
  def change
    remove_column :fee_recipients, :sent_at, :datetime
  end
end
