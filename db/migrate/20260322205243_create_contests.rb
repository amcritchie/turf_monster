class CreateContests < ActiveRecord::Migration[7.2]
  def change
    create_table :contests do |t|
      t.string :name, null: false
      t.integer :entry_fee_cents, default: 0, null: false
      t.string :status, default: "draft", null: false
      t.integer :max_entries
      t.datetime :starts_at

      t.timestamps
    end
  end
end
