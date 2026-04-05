class AddLevelToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :level, :integer, default: 1, null: false
  end
end
