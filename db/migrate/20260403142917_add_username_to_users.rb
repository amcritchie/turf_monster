class AddUsernameToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :username, :string
    add_index :users, "LOWER(username)", unique: true, name: "index_users_on_lower_username", where: "username IS NOT NULL"
  end
end
