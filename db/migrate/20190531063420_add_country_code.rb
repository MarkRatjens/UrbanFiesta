class AddCountryCode < ActiveRecord::Migration[5.2]
  def change
    add_column :credit_registrations, :country_code, :string
  end
end
