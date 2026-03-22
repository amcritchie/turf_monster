class AddPasswordDigestToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :password_digest, :string, null: false, default: ""
    change_column_null :users, :name, true
  end
end
