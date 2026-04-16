class AddLocksAtSnapshotToContests < ActiveRecord::Migration[7.2]
  def change
    add_column :contests, :locks_at_date_selected, :string
    add_column :contests, :locks_at_time_selected, :string
    add_column :contests, :locks_at_timezone_selected, :string
  end
end
