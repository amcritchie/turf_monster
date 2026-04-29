class CreateImageCaches < ActiveRecord::Migration[7.2]
  def change
    create_table :image_caches do |t|
      t.references :owner, polymorphic: true, null: false
      t.string :purpose, null: false
      t.string :variant, null: false
      t.string :s3_key, null: false
      t.string :source_url
      t.integer :bytes
      t.string :content_type
      t.timestamps
    end

    add_index :image_caches, [:owner_type, :owner_id, :purpose, :variant],
              unique: true, name: "idx_image_caches_owner_purpose_variant"
    add_index :image_caches, :s3_key, unique: true
  end
end
