require "rails_helper"

RSpec.describe Transaction, type: :model do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }

  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:account) }
    it { should belong_to(:category).optional }
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
      it "returns transactions ordered by transaction date (created_at_up or settled_at) desc" do
        old_transaction = create(:transaction, user: user, account: account, created_at_up: 2.days.ago, settled_at: 2.days.ago)
        new_transaction = create(:transaction, user: user, account: account, created_at_up: 1.day.ago, settled_at: 1.day.ago)

        # Scope to user to avoid interference from other test data
        results = Transaction.where(user: user).recent.to_a
        expect(results.first).to eq(new_transaction)
        expect(results.last).to eq(old_transaction)
      end

      it "uses created_at_up when settled_at is nil (HELD transactions)" do
        held_transaction = create(:transaction, user: user, account: account, created_at_up: 1.day.ago, settled_at: nil)
        settled_transaction = create(:transaction, user: user, account: account, created_at_up: 2.days.ago, settled_at: 2.days.ago)

        results = Transaction.where(user: user).recent.to_a
        expect(results.first).to eq(held_transaction)
        expect(results.last).to eq(settled_transaction)
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

    describe ".by_category" do
      let(:category1) { create(:category) }
      let(:category2) { create(:category) }

      it "returns transactions with matching category_id" do
        transaction1 = create(:transaction, user: user, account: account, category: category1)
        transaction2 = create(:transaction, user: user, account: account, category: category2)
        transaction3 = create(:transaction, user: user, account: account, category: nil)

        results = Transaction.by_category(category1.id)

        expect(results).to include(transaction1)
        expect(results).not_to include(transaction2)
        expect(results).not_to include(transaction3)
      end

      it "returns all transactions when category_id is nil" do
        transaction1 = create(:transaction, user: user, account: account, category: category1)
        transaction2 = create(:transaction, user: user, account: account, category: category2)

        results = Transaction.by_category(nil)

        expect(results).to include(transaction1, transaction2)
      end

      it "returns all transactions when category_id is empty string" do
        transaction1 = create(:transaction, user: user, account: account, category: category1)
        transaction2 = create(:transaction, user: user, account: account, category: category2)

        results = Transaction.by_category("")

        expect(results).to include(transaction1, transaction2)
      end
    end

    describe ".by_account" do
      let(:account2) { create(:account, user: user) }

      it "returns transactions with matching account_id" do
        transaction1 = create(:transaction, user: user, account: account)
        transaction2 = create(:transaction, user: user, account: account2)

        results = Transaction.by_account(account.id)

        expect(results).to include(transaction1)
        expect(results).not_to include(transaction2)
      end

      it "returns all transactions when account_id is nil" do
        transaction1 = create(:transaction, user: user, account: account)
        transaction2 = create(:transaction, user: user, account: account2)

        results = Transaction.by_account(nil)

        expect(results).to include(transaction1, transaction2)
      end

      it "returns all transactions when account_id is empty string" do
        transaction1 = create(:transaction, user: user, account: account)
        transaction2 = create(:transaction, user: user, account: account2)

        results = Transaction.by_account("")

        expect(results).to include(transaction1, transaction2)
      end
    end

    describe ".by_amount_range" do
      it "filters by min_amount only" do
        transaction1 = create(:transaction, user: user, account: account, amount_cents: -5000)  # 50.00 AUD
        transaction2 = create(:transaction, user: user, account: account, amount_cents: -1000)  # 10.00 AUD
        transaction3 = create(:transaction, user: user, account: account, amount_cents: 5000)   # 50.00 AUD

        results = Transaction.by_amount_range(20.0, nil)

        expect(results).to include(transaction1, transaction3)
        expect(results).not_to include(transaction2)
      end

      it "filters by max_amount only" do
        transaction1 = create(:transaction, user: user, account: account, amount_cents: -5000)  # 50.00 AUD
        transaction2 = create(:transaction, user: user, account: account, amount_cents: -10000) # 100.00 AUD
        transaction3 = create(:transaction, user: user, account: account, amount_cents: 5000)   # 50.00 AUD

        results = Transaction.by_amount_range(nil, 60.0)

        expect(results).to include(transaction1, transaction3)
        expect(results).not_to include(transaction2)
      end

      it "filters by both min_amount and max_amount" do
        transaction1 = create(:transaction, user: user, account: account, amount_cents: -5000)  # 50.00 AUD
        transaction2 = create(:transaction, user: user, account: account, amount_cents: -1000)  # 10.00 AUD
        transaction3 = create(:transaction, user: user, account: account, amount_cents: -10000) # 100.00 AUD

        results = Transaction.by_amount_range(20.0, 60.0)

        expect(results).to include(transaction1)
        expect(results).not_to include(transaction2, transaction3)
      end

      it "returns all transactions when both min and max are nil" do
        transaction1 = create(:transaction, user: user, account: account, amount_cents: -5000)
        transaction2 = create(:transaction, user: user, account: account, amount_cents: -1000)

        results = Transaction.by_amount_range(nil, nil)

        expect(results).to include(transaction1, transaction2)
      end

      it "uses absolute value for amount comparison" do
        expense = create(:transaction, user: user, account: account, amount_cents: -5000)  # 50.00 AUD
        income = create(:transaction, user: user, account: account, amount_cents: 5000)    # 50.00 AUD

        results = Transaction.by_amount_range(40.0, 60.0)

        expect(results).to include(expense, income)
      end
    end

    describe ".by_tag" do
      let(:tag1) { create(:tag) }
      let(:tag2) { create(:tag) }

      it "returns transactions with matching tag_id" do
        transaction1 = create(:transaction, user: user, account: account)
        transaction2 = create(:transaction, user: user, account: account)
        create(:transaction_tag, transaction_record: transaction1, tag: tag1)
        create(:transaction_tag, transaction_record: transaction2, tag: tag2)

        results = Transaction.by_tag(tag1.id)

        expect(results).to include(transaction1)
        expect(results).not_to include(transaction2)
      end

      it "returns distinct transactions when multiple tags match" do
        transaction1 = create(:transaction, user: user, account: account)
        create(:transaction_tag, transaction_record: transaction1, tag: tag1)
        create(:transaction_tag, transaction_record: transaction1, tag: tag2)

        results = Transaction.by_tag(tag1.id)

        expect(results.count).to eq(1)
        expect(results).to include(transaction1)
      end

      it "returns all transactions when tag_id is nil" do
        transaction1 = create(:transaction, user: user, account: account)
        transaction2 = create(:transaction, user: user, account: account)
        create(:transaction_tag, transaction_record: transaction1, tag: tag1)

        results = Transaction.by_tag(nil)

        expect(results).to include(transaction1, transaction2)
      end

      it "returns all transactions when tag_id is empty string" do
        transaction1 = create(:transaction, user: user, account: account)
        transaction2 = create(:transaction, user: user, account: account)
        create(:transaction_tag, transaction_record: transaction1, tag: tag1)

        results = Transaction.by_tag("")

        expect(results).to include(transaction1, transaction2)
      end

      it "excludes transactions without the tag" do
        transaction_with_tag = create(:transaction, user: user, account: account)
        transaction_without_tag = create(:transaction, user: user, account: account)
        create(:transaction_tag, transaction_record: transaction_with_tag, tag: tag1)

        results = Transaction.by_tag(tag1.id)

        expect(results).to include(transaction_with_tag)
        expect(results).not_to include(transaction_without_tag)
      end
    end

    describe ".by_description" do
      it "returns transactions matching description" do
        transaction1 = create(:transaction, user: user, account: account, description: "Coffee Shop Purchase")
        transaction2 = create(:transaction, user: user, account: account, description: "Grocery Store")

        results = Transaction.by_description("Coffee")

        expect(results).to include(transaction1)
        expect(results).not_to include(transaction2)
      end

      it "returns transactions matching message" do
        transaction1 = create(:transaction, user: user, account: account, message: "Payment to Coffee Shop")
        transaction2 = create(:transaction, user: user, account: account, message: "Payment to Grocery Store")

        results = Transaction.by_description("Coffee")

        expect(results).to include(transaction1)
        expect(results).not_to include(transaction2)
      end

      it "returns transactions matching either description or message" do
        transaction1 = create(:transaction, user: user, account: account, description: "Coffee Shop", message: nil)
        transaction2 = create(:transaction, user: user, account: account, description: nil, message: "Coffee Shop")
        transaction3 = create(:transaction, user: user, account: account, description: "Grocery Store", message: nil)

        results = Transaction.by_description("Coffee")

        expect(results).to include(transaction1, transaction2)
        expect(results).not_to include(transaction3)
      end

      it "performs case-insensitive search" do
        transaction1 = create(:transaction, user: user, account: account, description: "Coffee Shop")
        transaction2 = create(:transaction, user: user, account: account, description: "COFFEE SHOP")
        transaction3 = create(:transaction, user: user, account: account, description: "coffee shop")

        results = Transaction.by_description("coffee")

        expect(results).to include(transaction1, transaction2, transaction3)
      end

      it "performs partial match search" do
        transaction1 = create(:transaction, user: user, account: account, description: "Coffee Shop Purchase")
        transaction2 = create(:transaction, user: user, account: account, description: "Coffee")

        results = Transaction.by_description("Coffee")

        expect(results).to include(transaction1, transaction2)
      end

      it "returns all transactions when query is nil" do
        transaction1 = create(:transaction, user: user, account: account, description: "Coffee Shop")
        transaction2 = create(:transaction, user: user, account: account, description: "Grocery Store")

        results = Transaction.by_description(nil)

        expect(results).to include(transaction1, transaction2)
      end

      it "returns all transactions when query is empty string" do
        transaction1 = create(:transaction, user: user, account: account, description: "Coffee Shop")
        transaction2 = create(:transaction, user: user, account: account, description: "Grocery Store")

        results = Transaction.by_description("")

        expect(results).to include(transaction1, transaction2)
      end
    end
  end

  describe ".find_or_create_from_up_data" do
    let!(:category) { create(:category, up_id: "test-category-id", name: "Groceries") }

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
          "createdAt" => "2024-01-01T10:00:00Z",
          "settledAt" => "2024-01-01T12:00:00Z",
          "roundUp" => {
            "amount" => {
              "valueInBaseUnits" => 50
            }
          },
          "cashback" => {
            "amount" => {
              "valueInBaseUnits" => 25
            }
          }
        },
        "relationships" => {
          "account" => {
            "data" => {
              "id" => account.up_id
            }
          },
          "category" => {
            "data" => {
              "id" => "test-category-id",
              "type" => "categories"
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
      expect(transaction.created_at_up).to be_present
      expect(transaction.settled_at).to be_present
    end

    it "assigns category from relationships" do
      transaction = Transaction.find_or_create_from_up_data(up_data, user, account)

      expect(transaction.category).to eq(category)
    end

    it "stores roundUp amount" do
      transaction = Transaction.find_or_create_from_up_data(up_data, user, account)

      expect(transaction.round_up_cents).to eq(50)
    end

    it "stores cashback amount" do
      transaction = Transaction.find_or_create_from_up_data(up_data, user, account)

      expect(transaction.cashback_cents).to eq(25)
    end

    it "handles transactions without category" do
      up_data_no_category = up_data.deep_dup
      up_data_no_category["relationships"].delete("category")

      transaction = Transaction.find_or_create_from_up_data(up_data_no_category, user, account)

      expect(transaction.category).to be_nil
    end

    it "handles HELD transactions without settledAt" do
      held_data = up_data.deep_dup
      held_data["attributes"]["status"] = "HELD"
      held_data["attributes"].delete("settledAt")

      transaction = Transaction.find_or_create_from_up_data(held_data, user, account)

      expect(transaction.status).to eq("held")
      expect(transaction.settled_at).to be_nil
      expect(transaction.created_at_up).to be_present
    end
  end
end
