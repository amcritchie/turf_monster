class AddRankAndPayoutToEntries < ActiveRecord::Migration[7.2]
  def change
    add_column :entries, :rank, :integer
    add_column :entries, :payout_cents, :integer, default: 0
  end
end
