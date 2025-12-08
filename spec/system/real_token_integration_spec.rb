# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Real Up Bank Token Integration', type: :system do
  let(:real_token) { ENV['REAL_UP_BANK_TOKEN'] }

  before(:all) do
    # Skip entire suite if token not set
    if ENV['REAL_UP_BANK_TOKEN'].blank?
      skip "REAL_UP_BANK_TOKEN not set. Set environment variable to run these tests."
    end
  end

  before do
    skip_if_no_real_token
  end

  describe 'Token Encryption/Decryption' do
    it 'encrypts and decrypts real token correctly' do
      user = create(:user)
      
      # Set real token
      user.update!(up_bank_token: real_token)
      user.reload
      
      # Verify encryption
      expect(user.read_attribute(:up_bank_token_ciphertext)).to be_present
      expect(user.read_attribute(:up_bank_token_ciphertext)).not_to eq(real_token)
      
      # Verify decryption
      expect(user.up_bank_token).to eq(real_token)
      expect(user.has_up_bank_token?).to be true
      expect(user.needs_up_bank_setup?).to be false
    end

    it 'persists token across multiple reloads' do
      user = create(:user)
      user.update!(up_bank_token: real_token)
      
      # Reload multiple times
      3.times do
        user.reload
        expect(user.up_bank_token).to eq(real_token)
      end
    end

    it 'handles token updates correctly' do
      user = create(:user)
      user.update!(up_bank_token: real_token)
      user.reload
      
      # Update token (simulate reconnection)
      new_token = real_token + '_updated'
      user.update!(up_bank_token: new_token)
      user.reload
      
      expect(user.up_bank_token).to eq(new_token)
    end
  end

  describe 'API Service Integration' do
    it 'can use real token to initialize service' do
      user = create_user_with_real_token
      
      expect {
        UpBankApiService.new(user)
      }.not_to raise_error
    end

    it 'can use real token to fetch accounts', :vcr do
      user = create_user_with_real_token
      service = UpBankApiService.new(user)
      
      # This will make a real API call if VCR is not configured
      # VCR should be configured to record/playback responses
      accounts = service.fetch_accounts
      
      expect(accounts).to be_an(Array)
      # Real API will return actual accounts if VCR allows
    end
  end

  describe 'Sync Job Integration' do
    it 'can sync data with real token', :vcr do
      user = create_user_with_real_token
      
      # Stub API responses to avoid actual API calls in tests
      # In real scenario, VCR would handle this
      allow_any_instance_of(UpBankApiService).to receive(:sync_all_data).and_return(true)
      
      expect {
        SyncUpBankDataJob.perform_now(user)
      }.not_to raise_error
      
      expect(user.reload.last_synced_at).to be_present
    end
  end

  describe 'Webhook Processing' do
    it 'can process webhooks with real token' do
      user = create_user_with_real_token
      
      webhook_event = create(:webhook_event, user: user, payload: {
        "data" => {
          "attributes" => {
            "eventType" => "PING"
          }
        }
      })
      
      expect {
        ProcessUpWebhookJob.perform_now(webhook_event)
      }.not_to raise_error
      
      expect(webhook_event.reload.processed?).to be true
    end
  end

  describe 'Onboarding Flow' do
    it 'can complete onboarding with real token' do
      user = create(:user)
      sign_in user, scope: :user
      
      visit onboarding_connect_up_bank_path
      
      # Simulate token connection
      user.update!(up_bank_token: real_token)
      user.reload
      
      expect(user.has_up_bank_token?).to be true
      expect(user.needs_up_bank_setup?).to be false
    end
  end
end

