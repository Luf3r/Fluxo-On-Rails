# frozen_string_literal: true

class ConvertUsersPrimaryKeyToUuidV7 < ActiveRecord::Migration[8.1]
  def up
    return if uuid_primary_key?(:users)

    add_column :users, :uuid_id, :uuid

    connection.select_values("SELECT id FROM users").each do |id|
      execute <<~SQL.squish
        UPDATE users
        SET uuid_id = #{connection.quote(SecureRandom.uuid_v7)}
        WHERE id = #{connection.quote(id)}
      SQL
    end

    change_column_null :users, :uuid_id, false
    execute "ALTER TABLE users DROP CONSTRAINT IF EXISTS users_pkey"
    remove_column :users, :id
    rename_column :users, :uuid_id, :id
    execute "ALTER TABLE users ADD PRIMARY KEY (id)"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot safely convert UUID primary keys back to integer IDs"
  end

  private

  def uuid_primary_key?(table_name)
    connection.columns(table_name).find { |column| column.name == "id" }&.type == :uuid
  end
end
