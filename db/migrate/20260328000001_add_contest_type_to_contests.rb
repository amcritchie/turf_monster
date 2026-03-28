class AddContestTypeToContests < ActiveRecord::Migration[7.2]
  def change
    add_column :contests, :contest_type, :string, default: "over_under", null: false
  end
end
