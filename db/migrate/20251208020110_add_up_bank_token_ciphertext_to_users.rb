class AddUpBankTokenCiphertextToUsers < ActiveRecord::Migration[8.0]
  def change
    # Rails encryption stores encrypted data in <attribute>_ciphertext column
    add_column :users, :up_bank_token_ciphertext, :text unless column_exists?(:users, :up_bank_token_ciphertext)
  end
end
