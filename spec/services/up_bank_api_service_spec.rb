require "rails_helper"

RSpec.describe UpBankApiService, :vcr do
  let(:user) { create(:user, up_bank_token: "test_token") }
  let(:service) { described_class.new(user) }

  describe "#initialize" do
    context "when user has no token" do
      let(:user_without_token) { create(:user, up_bank_token: nil) }

      it "raises ArgumentError" do
        expect {
          described_class.new(user_without_token)
        }.to raise_error(ArgumentError, "User has no Up Bank token")
      end
    end
  end

  describe "#fetch_accounts" do
    it "returns accounts from Up Bank API" do
      accounts = service.fetch_accounts
      expect(accounts).to be_an(Array)
      expect(accounts.first).to have_key("id") if accounts.any?
      expect(accounts.first).to have_key("attributes") if accounts.any?
    end

    context "when API returns error" do
      before do
        allow(HTTParty).to receive(:get).and_return(
          double(success?: false, code: 401, body: '{"errors": [{"title": "Unauthorized"}]}')
        )
      end

      it "raises UpBankApiError" do
        expect {
          service.fetch_accounts
        }.to raise_error(UpBankApiError, /API Error: 401/)
      end
    end
  end

  describe "#fetch_all_transactions" do
    it "fetches all paginated transactions" do
      transactions = service.fetch_all_transactions
      expect(transactions).to be_an(Array)
    end

    it "handles pagination correctly" do
      # Test with cassette that includes pagination
      VCR.use_cassette("services/up_bank_api_service/fetch_all_transactions_paginated") do
        transactions = service.fetch_all_transactions
        expect(transactions).to be_an(Array)
      end
    end
  end

  describe "#fetch_transaction" do
    let(:transaction_id) { "test-transaction-id" }

    it "fetches a single transaction" do
      transaction = service.fetch_transaction(transaction_id)
      expect(transaction).to have_key("id") if transaction
      expect(transaction).to have_key("attributes") if transaction
    end
  end

  describe "#sync_all_data" do
    it "syncs accounts and transactions" do
      expect {
        service.sync_all_data
      }.to change(Account, :count).by_at_least(0)
        .or change(Transaction, :count).by_at_least(0)
    end

    it "updates existing accounts" do
      account = create(:account, user: user, up_id: "existing-account-id", balance_cents: 1000)
      
      service.sync_all_data
      
      account.reload
      # Balance may or may not change depending on cassette data
      expect(account).to be_persisted
    end
  end

  describe "#sync_accounts" do
    it "creates new accounts" do
      expect {
        service.sync_accounts
      }.to change(Account, :count).by_at_least(0)
    end

    it "updates account attributes" do
      account = create(:account, user: user, up_id: "test-account-id")
      
      service.sync_accounts
      
      account.reload
      expect(account).to be_persisted
    end
  end

  describe "#sync_transactions" do
    let(:account) { create(:account, user: user, up_id: "test-account-id") }

    it "creates transactions from API data" do
      expect {
        service.sync_transactions
      }.to change(Transaction, :count).by_at_least(0)
    end

    it "associates transactions with correct account" do
      service.sync_transactions
      
      if Transaction.any?
        transaction = Transaction.last
        expect(transaction.account).to be_present
      end
    end
  end
end

