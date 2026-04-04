class AddInvitedByToUsers < ActiveRecord::Migration[7.2]
  def change
    add_reference :users, :invited_by, foreign_key: { to_table: :users }, null: true
  end
end
