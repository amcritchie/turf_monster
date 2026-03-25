class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string :name
      t.string :email
      t.integer :balance_cents, default: 0, null: false
      t.string :password_digest, default: "", null: false
      t.string :provider
      t.string :uid
      t.string :wallet_address
      t.string :slug
      t.string :first_name
      t.string :last_name
      t.date :birth_date
      t.integer :birth_year
      t.timestamps
    end

    add_index :users, :email, unique: true, where: "email IS NOT NULL"
    add_index :users, :wallet_address, unique: true, where: "wallet_address IS NOT NULL"
    add_index :users, [:provider, :uid], unique: true, where: "provider IS NOT NULL"
  end
end
