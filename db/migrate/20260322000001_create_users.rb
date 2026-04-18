class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string :name
      t.string :email
      t.string :username
      t.string :first_name
      t.string :last_name
      t.date :birth_date
      t.integer :birth_year
      t.string :password_digest, default: "", null: false
      t.string :provider
      t.string :uid
      t.string :role, default: "viewer"
      t.integer :level, default: 1, null: false
      t.string :web2_solana_address
      t.string :web3_solana_address
      t.text :encrypted_web2_solana_private_key
      t.bigint :invited_by_id
      t.string :slug
      t.timestamps
    end

    add_index :users, :email, unique: true, where: "email IS NOT NULL"
    add_index :users, "lower(username)", unique: true, where: "username IS NOT NULL", name: "index_users_on_lower_username"
    add_index :users, [:provider, :uid], unique: true, where: "provider IS NOT NULL"
    add_index :users, :web2_solana_address, unique: true, where: "web2_solana_address IS NOT NULL"
    add_index :users, :web3_solana_address, unique: true, where: "web3_solana_address IS NOT NULL"
    add_index :users, :slug, unique: true
    add_index :users, :invited_by_id
    add_foreign_key :users, :users, column: :invited_by_id
  end
end
