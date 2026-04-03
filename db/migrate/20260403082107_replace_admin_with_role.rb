class ReplaceAdminWithRole < ActiveRecord::Migration[7.2]
  def up
    add_column :users, :role, :string, default: "viewer"

    # Copy existing admin flags
    execute <<-SQL
      UPDATE users SET role = 'admin' WHERE admin = true
    SQL

    remove_column :users, :admin
  end

  def down
    add_column :users, :admin, :boolean, default: false, null: false

    execute <<-SQL
      UPDATE users SET admin = true WHERE role = 'admin'
    SQL

    remove_column :users, :role
  end
end
