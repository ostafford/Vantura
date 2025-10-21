class AddUpBankTokenToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :up_bank_token, :text
  end
end
