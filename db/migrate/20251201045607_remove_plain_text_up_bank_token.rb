class RemovePlainTextUpBankToken < ActiveRecord::Migration[8.0]
  def up
    # First, ensure encrypted columns exist
    unless column_exists?(:users, :up_bank_token_encrypted)
      raise "Encrypted columns don't exist! Run AddUpBankTokenToUsers migration first."
    end

    # If plain text column has data, encrypt it first
    if column_exists?(:users, :up_bank_token)
      say_with_time "Migrating plain text tokens to encrypted storage" do
        User.find_each do |user|
          if user.read_attribute(:up_bank_token).present? && user.up_bank_token_encrypted.blank?
            # This will use attr_encrypted to encrypt the value
            user.up_bank_token = user.read_attribute(:up_bank_token)
            user.save!(validate: false)
          end
        end
      end

      # Now safe to remove plain text column
      remove_column :users, :up_bank_token, :text
    end
  end

  def down
    add_column :users, :up_bank_token, :text unless column_exists?(:users, :up_bank_token)
  end
end
