class AddPromotionalCentsToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :promotional_cents, :integer, default: 0, null: false
  end
end
