require "rails_helper"

RSpec.describe Transaction, type: :model do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }

  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:account) }
    # Category association removed - transactions table doesn't have category_id
    # it { should belong_to(:category).optional }
    it { should have_many(:transaction_tags).dependent(:destroy) }
    it { should have_many(:tags).through(:transaction_tags) }
  end

  describe "validations" do
    subject { build(:transaction, user: user, account: account) }
    
    it { should validate_presence_of(:up_id) }
    it { should validate_uniqueness_of(:up_id).scoped_to(:user_id) }
    it { should validate_presence_of(:status) }
    
    it "allows same up_id for different users" do
      user2 = create(:user)
      account2 = create(:account, user: user2)
      transaction1 = create(:transaction, user: user, account: account, up_id: "same-id")
      transaction2 = build(:transaction, user: user2, account: account2, up_id: "same-id")
      
      expect(transaction2).to be_valid
    end
  end

  describe "enums" do
    it { should define_enum_for(:status).with_values(held: "HELD", settled: "SETTLED", pending: "PENDING").backed_by_column_of_type(:string) }
  end

  describe "scopes" do
    describe ".recent" do
      it "returns transactions ordered by created_at desc" do
        old_transaction = create(:transaction, user: user, account: account, created_at: 2.days.ago)
        new_transaction = create(:transaction, user: user, account: account, created_at: 1.day.ago)
        
        expect(Transaction.recent.first).to eq(new_transaction)
        expect(Transaction.recent.last).to eq(old_transaction)
      end
    end

    describe ".by_date_range" do
      it "returns transactions within date range" do
        in_range = create(:transaction, user: user, account: account, created_at: 5.days.ago)
        out_of_range = create(:transaction, user: user, account: account, created_at: 10.days.ago)
        
        results = Transaction.by_date_range(7.days.ago, 1.day.ago)
        
        expect(results).to include(in_range)
        expect(results).not_to include(out_of_range)
      end
    end

    describe ".expenses" do
      it "returns transactions with negative amount" do
        expense = create(:transaction, user: user, account: account, amount_cents: -1000)
        income = create(:transaction, user: user, account: account, amount_cents: 1000)
        
        expect(Transaction.expenses).to include(expense)
        expect(Transaction.expenses).not_to include(income)
      end
    end

    describe ".income" do
      it "returns transactions with positive amount" do
        expense = create(:transaction, user: user, account: account, amount_cents: -1000)
        income = create(:transaction, user: user, account: account, amount_cents: 1000)
        
        expect(Transaction.income).to include(income)
        expect(Transaction.income).not_to include(expense)
      end
    end
  end

  describe ".find_or_create_from_up_data" do
    let(:up_data) do
      {
        "id" => "test-transaction-id",
        "attributes" => {
          "status" => "SETTLED",
          "rawText" => "Test transaction",
          "description" => "Test Description",
          "message" => "Test Message",
          "amount" => {
            "valueInBaseUnits" => -1000
          },
          "settledAt" => "2024-01-01T00:00:00Z"
        },
        "relationships" => {
          "account" => {
            "data" => {
              "id" => account.up_id
            }
          }
        }
      }
    end

    it "creates a new transaction" do
      expect {
        Transaction.find_or_create_from_up_data(up_data, user, account)
      }.to change(Transaction, :count).by(1)
    end

    it "updates existing transaction" do
      existing = create(:transaction, user: user, account: account, up_id: "test-transaction-id", description: "Old")
      
      Transaction.find_or_create_from_up_data(up_data, user, account)
      
      existing.reload
      expect(existing.description).to eq("Test Description")
    end

    it "sets correct attributes" do
      transaction = Transaction.find_or_create_from_up_data(up_data, user, account)
      
      expect(transaction.up_id).to eq("test-transaction-id")
      expect(transaction.status).to eq("settled")
      expect(transaction.raw_text).to eq("Test transaction")
      expect(transaction.description).to eq("Test Description")
      expect(transaction.amount_cents).to eq(-1000)
    end
  end
end

