class AddXpToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :xp_points, :integer, default: 0, null: false
    add_column :users, :level, :integer, default: 0, null: false
    add_column :users, :free_entry_tokens, :integer, default: 0, null: false
  end
end
