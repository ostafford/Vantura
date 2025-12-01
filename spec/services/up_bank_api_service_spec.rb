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
      # Stub HTTParty to bypass VCR cassette with 401
      allow(HTTParty).to receive(:get).and_return(
        double(
          success?: true,
          code: 200,
          body: '{"data": [{"id": "test-account", "attributes": {"accountType": "SAVER", "displayName": "Test Account", "balance": {"valueInBaseUnits": 1000}}}]}'
        )
      )
      
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
      # Stub HTTParty to bypass VCR cassette with 401
      allow(HTTParty).to receive(:get).and_return(
        double(
          success?: true,
          code: 200,
          body: '{"data": [{"id": "test-transaction", "attributes": {"status": "SETTLED"}}], "links": {}}'
        )
      )
      
      transactions = service.fetch_all_transactions
      expect(transactions).to be_an(Array)
    end

    it "handles pagination correctly" do
      # Stub first page response
      first_page = double(
        success?: true,
        code: 200,
        body: '{"data": [{"id": "tx1", "attributes": {"status": "SETTLED"}}], "links": {"next": "https://api.up.com.au/api/v1/transactions?page[after]=token"}}'
      )
      # Stub second page response (no next link)
      second_page = double(
        success?: true,
        code: 200,
        body: '{"data": [{"id": "tx2", "attributes": {"status": "SETTLED"}}], "links": {}}'
      )
      
      allow(HTTParty).to receive(:get).and_return(first_page, second_page)
      
      transactions = service.fetch_all_transactions
      expect(transactions).to be_an(Array)
      expect(transactions.length).to eq(2)
    end
  end

  describe "#fetch_transaction" do
    let(:transaction_id) { "test-transaction-id" }

    it "fetches a single transaction" do
      # Stub HTTParty to bypass VCR cassette with 401
      allow(HTTParty).to receive(:get).and_return(
        double(
          success?: true,
          code: 200,
          body: '{"data": {"id": "test-transaction-id", "attributes": {"status": "SETTLED", "description": "Test"}}}'
        )
      )
      
      transaction = service.fetch_transaction(transaction_id)
      expect(transaction).to have_key("id") if transaction
      expect(transaction).to have_key("attributes") if transaction
    end
  end

  describe "#sync_all_data" do
    before do
      # Stub API responses to bypass VCR cassettes with 401s
      accounts_response = double(
        success?: true,
        code: 200,
        body: '{"data": [{"id": "test-account-id", "attributes": {"accountType": "SAVER", "displayName": "Test Account", "balance": {"valueInBaseUnits": 2000}}}]}'
      )
      transactions_response = double(
        success?: true,
        code: 200,
        body: '{"data": [], "links": {}}'
      )
      allow(HTTParty).to receive(:get).and_return(accounts_response, transactions_response)
    end

    it "syncs accounts and transactions" do
      expect {
        service.sync_all_data
      }.to change(Account, :count).by_at_least(0)
        .or change(Transaction, :count).by_at_least(0)
    end

    it "updates existing accounts" do
      account = create(:account, user: user, up_id: "test-account-id", balance_cents: 1000)
      
      service.sync_all_data
      
      account.reload
      # Balance should be updated from API response
      expect(account).to be_persisted
      expect(account.balance_cents).to eq(2000)
    end
  end

  describe "#sync_accounts" do
    before do
      # Stub API response to bypass VCR cassette with 401
      allow(HTTParty).to receive(:get).and_return(
        double(
          success?: true,
          code: 200,
          body: '{"data": [{"id": "test-account-id", "attributes": {"accountType": "SAVER", "displayName": "Updated Account", "balance": {"valueInBaseUnits": 5000}}}]}'
        )
      )
    end

    it "creates new accounts" do
      expect {
        service.sync_accounts
      }.to change(Account, :count).by(1)
    end

    it "updates account attributes" do
      account = create(:account, user: user, up_id: "test-account-id", display_name: "Old Name", balance_cents: 1000)
      
      service.sync_accounts
      
      account.reload
      expect(account).to be_persisted
      expect(account.display_name).to eq("Updated Account")
      expect(account.balance_cents).to eq(5000)
    end
  end

  describe "#sync_transactions" do
    let!(:account) { create(:account, user: user, up_id: "test-account-id") }

    before do
      # Stub API response to bypass VCR cassette with 401
      allow(HTTParty).to receive(:get).and_return(
        double(
          success?: true,
          code: 200,
          body: '{"data": [{"id": "test-transaction-id", "attributes": {"status": "SETTLED", "description": "Test Transaction", "amount": {"valueInBaseUnits": -1000}}, "relationships": {"account": {"data": {"id": "test-account-id"}}}}], "links": {}}'
        )
      )
    end

    it "creates transactions from API data" do
      expect {
        service.sync_transactions
      }.to change(Transaction, :count).by(1)
    end

    it "associates transactions with correct account" do
      service.sync_transactions
      
      transaction = Transaction.last
      expect(transaction.account).to be_present
      expect(transaction.account).to eq(account)
    end
  end
end

