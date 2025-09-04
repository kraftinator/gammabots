class AddStatusToBots < ActiveRecord::Migration[7.2]
  def change
    add_column :bots, :status, :string, null: false, default: "pending_funding"
    add_index  :bots, :status

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE bots
          SET status = CASE
            WHEN active IS TRUE THEN 'active'
            ELSE 'inactive'
          END;
        SQL
      end
    end
  end
end
