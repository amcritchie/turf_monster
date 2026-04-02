class AddTaglineToContests < ActiveRecord::Migration[7.2]
  def change
    add_column :contests, :tagline, :string
  end
end
