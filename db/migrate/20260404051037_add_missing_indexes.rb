class AddMissingIndexes < ActiveRecord::Migration[7.2]
  def change
    add_index :contests, :slug, unique: true
    add_index :contests, :status
    add_index :entries, :status
    add_index :entries, :slug, unique: true
  end
end
