class AddReferralCodes < ActiveRecord::Migration[5.2]
  def change
    add_column :credit_registrations, :referrer_code, :string
    add_column :credit_registrations, :referee_code, :string
  end
end
