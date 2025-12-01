class AddSignupSignedAtToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :signup_signed_at, :datetime
  end
end
