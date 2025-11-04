class AddValidationFieldsToTokens < ActiveRecord::Migration[7.2]
  def up
    add_column :tokens, :status, :string, null: false, default: "pending_validation"
    add_column :tokens, :validation_payload, :jsonb, null: true
    add_column :tokens, :last_validated_at, :datetime, null: true

    add_index :tokens, :status

    # Backfill existing tokens so you don't disrupt running bots
    execute <<~SQL.squish
      UPDATE tokens
      SET status = 'active'
      WHERE status IS NULL OR status = 'pending_validation';
    SQL
  end

  def down
    remove_index  :tokens, :status
    remove_column :tokens, :last_validated_at
    remove_column :tokens, :validation_payload
    remove_column :tokens, :status
  end
end
