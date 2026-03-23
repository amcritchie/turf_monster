class RemoveUniqueIndexOnEntries < ActiveRecord::Migration[7.2]
  def change
    remove_index :entries, [:user_id, :contest_id]
    add_index :entries, [:user_id, :contest_id]
  end
end
