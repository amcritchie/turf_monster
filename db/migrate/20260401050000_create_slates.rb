class CreateSlates < ActiveRecord::Migration[7.2]
  def change
    create_table :slates do |t|
      t.string :name, null: false
      t.datetime :starts_at
      t.string :slug

      t.timestamps
    end

    add_index :slates, :slug, unique: true
  end
end
