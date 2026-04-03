class ChangeContestTypeDefault < ActiveRecord::Migration[7.2]
  def change
    change_column_default :contests, :contest_type, from: "over_under", to: "small"
  end
end
