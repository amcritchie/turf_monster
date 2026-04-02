class AddDecimalOddsToSlateMatchups < ActiveRecord::Migration[7.2]
  def change
    add_column :slate_matchups, :over_decimal_odds, :decimal, precision: 4, scale: 2
    add_column :slate_matchups, :under_decimal_odds, :decimal, precision: 4, scale: 2
  end
end
