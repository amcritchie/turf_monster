class AddRankToContests < ActiveRecord::Migration[7.2]
  def change
    add_column :contests, :rank, :integer
    add_index :contests, :rank
  end
end
