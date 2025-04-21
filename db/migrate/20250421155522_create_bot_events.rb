class CreateBotEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :bot_events do |t|
      t.references :bot,         null: false, foreign_key: true
      t.string     :event_type,  null: false
      t.jsonb      :payload,     null: false, default: {}
      t.timestamps
    end

    add_index :bot_events, [:bot_id, :event_type, :created_at]
    add_index :bot_events, :created_at
  end
end
