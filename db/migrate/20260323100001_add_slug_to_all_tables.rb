class AddSlugToAllTables < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :slug, :string
    add_column :contests, :slug, :string
    add_column :props, :slug, :string
    add_column :entries, :slug, :string
    add_column :picks, :slug, :string
  end
end
