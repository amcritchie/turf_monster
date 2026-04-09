class CreateErrorLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :error_logs do |t|
      t.text :message, null: false
      t.text :inspect
      t.text :backtrace
      t.string :target_type
      t.bigint :target_id
      t.string :target_name
      t.string :parent_type
      t.bigint :parent_id
      t.string :parent_name
      t.string :slug
      t.timestamps
    end

    add_index :error_logs, :created_at
    add_index :error_logs, [:target_type, :target_id]
    add_index :error_logs, [:parent_type, :parent_id]
  end
end
