class RenameCustodialToManagedWalletType < ActiveRecord::Migration[7.2]
  def up
    User.where(wallet_type: "custodial").update_all(wallet_type: "managed")
  end

  def down
    User.where(wallet_type: "managed").update_all(wallet_type: "custodial")
  end
end
