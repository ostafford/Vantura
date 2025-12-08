# frozen_string_literal: true

# Helper module for testing with real Up Bank tokens
# DO NOT commit real tokens to version control
# Set REAL_UP_BANK_TOKEN environment variable for testing
module RealTokenTestHelper
  # Get real token from environment variable
  def real_up_bank_token
    ENV['REAL_UP_BANK_TOKEN']
  end

  # Skip test if real token is not set
  def skip_if_no_real_token
    skip "REAL_UP_BANK_TOKEN not set. Set environment variable to run this test." unless real_up_bank_token
  end

  # Create a user with a real token for testing
  def create_user_with_real_token
    user = create(:user)
    user.update!(up_bank_token: real_up_bank_token)
    user.reload
    user
  end

  # Verify token is properly encrypted
  def verify_token_encryption(user)
    expect(user.read_attribute(:up_bank_token_ciphertext)).to be_present
    expect(user.read_attribute(:up_bank_token_ciphertext)).not_to eq(real_up_bank_token)
    expect(user.up_bank_token).to eq(real_up_bank_token)
  end
end

RSpec.configure do |config|
  config.include RealTokenTestHelper, type: :system
  config.include RealTokenTestHelper, type: :service
end
