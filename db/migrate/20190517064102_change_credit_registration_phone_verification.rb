class ChangeCreditRegistrationPhoneVerification < ActiveRecord::Migration[5.2]
  def change
    remove_column :credit_registrations, :carrier, :string
    remove_column :credit_registrations, :is_cellphone, :boolean
    remove_column :credit_registrations, :message, :string
    remove_column :credit_registrations, :uuid, :string
    rename_column :credit_registrations, :is_approved, :is_checked
  end
end
