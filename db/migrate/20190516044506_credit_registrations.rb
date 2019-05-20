class CreditRegistrations < ActiveRecord::Migration[5.2]
  def change
    create_table :credit_registrations do |t|
      t.string :situation
      t.string :email
      t.string :phone
      t.string :carrier
      t.boolean :is_cellphone
      t.string :message
      t.string :uuid
      t.boolean :is_approved
      t.timestamps
    end
  end
end
