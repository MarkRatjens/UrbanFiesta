class AddEmailIsChecked < ActiveRecord::Migration[5.2]
 def change
   rename_column :credit_registrations, :is_checked, :phone_is_checked
   add_column :credit_registrations, :email_is_checked, :boolean
 end
end
