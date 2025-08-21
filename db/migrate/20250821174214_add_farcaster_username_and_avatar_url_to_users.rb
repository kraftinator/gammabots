class AddFarcasterUsernameAndAvatarUrlToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :farcaster_username, :string
    add_column :users, :farcaster_avatar_url, :string
  end
end
