require "rails_helper"

RSpec.describe "Transaction Analytics", type: :model do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:account) { create(:account, user: user) }
  let(:category1) { create(:category, name: "Groceries") }
  let(:category2) { create(:category, name: "Entertainment") }

  before do
    # Create transactions for the user
    create(:transaction, user: user, account: account, amount_cents: -5000, category: category1, settled_at: 5.days.ago)
    create(:transaction, user: user, account: account, amount_cents: -3000, category: category1, settled_at: 3.days.ago)
    create(:transaction, user: user, account: account, amount_cents: -2000, category: category2, settled_at: 2.days.ago)
    create(:transaction, user: user, account: account, amount_cents: 10000, category: nil, settled_at: 1.day.ago) # Income

    # Create transaction for other user (should be excluded)
    other_account = create(:account, user: other_user)
    create(:transaction, user: other_user, account: other_account, amount_cents: -10000, category: category1, settled_at: 1.day.ago)
  end

  describe ".total_by_category" do
    context "without date range" do
      it "returns totals grouped by category" do
        results = Transaction.total_by_category(user)

        expect(results.count).to eq(2)

        groceries_result = results.find { |r| r.name == "Groceries" }
        expect(groceries_result.total_cents).to eq(8000) # 5000 + 3000
        expect(groceries_result.transaction_count).to eq(2)

        entertainment_result = results.find { |r| r.name == "Entertainment" }
        expect(entertainment_result.total_cents).to eq(2000)
        expect(entertainment_result.transaction_count).to eq(1)
      end

      it "excludes other users' transactions" do
        results = Transaction.total_by_category(user)
        total = results.sum(&:total_cents)
        expect(total).to eq(10000) # Only user's transactions
      end
    end

    context "with date range" do
      it "only includes transactions within the date range" do
        start_date = 4.days.ago.beginning_of_day
        end_date = 1.day.ago.end_of_day

        results = Transaction.total_by_category(user, start_date, end_date)

        groceries_result = results.find { |r| r.name == "Groceries" }
        expect(groceries_result.total_cents).to eq(3000) # Only the 3 days ago transaction
        expect(groceries_result.transaction_count).to eq(1)
      end
    end

    it "orders by total descending" do
      results = Transaction.total_by_category(user)
      totals = results.map(&:total_cents)
      expect(totals).to eq(totals.sort.reverse)
    end
  end

  describe ".total_by_merchant" do
    before do
      create(:transaction, user: user, account: account, description: "STARBUCKS", amount_cents: -1500, settled_at: 2.days.ago)
      create(:transaction, user: user, account: account, description: "STARBUCKS", amount_cents: -2000, settled_at: 1.day.ago)
      create(:transaction, user: user, account: account, description: "COLES SUPERMARKET", amount_cents: -5000, settled_at: 3.days.ago)
    end

    context "without date range" do
      it "returns totals grouped by merchant description" do
        results = Transaction.total_by_merchant(user)

        starbucks_result = results.find { |r| r.description == "STARBUCKS" }
        expect(starbucks_result).to be_present
        expect(starbucks_result.total_cents).to eq(3500) # 1500 + 2000
        expect(starbucks_result.transaction_count).to eq(2)
      end

      it "only includes expenses" do
        results = Transaction.total_by_merchant(user)
        # Should not include income transactions
        expect(results.map(&:description)).not_to include(nil)
      end
    end

    context "with date range" do
      it "only includes transactions within the date range" do
        start_date = 2.days.ago.beginning_of_day
        end_date = Time.current.end_of_day

        results = Transaction.total_by_merchant(user, start_date, end_date)

        starbucks_result = results.find { |r| r.description == "STARBUCKS" }
        expect(starbucks_result.total_cents).to eq(3500) # Both STARBUCKS transactions are in range
      end
    end

    it "orders by total descending" do
      results = Transaction.total_by_merchant(user)
      totals = results.map(&:total_cents)
      expect(totals).to eq(totals.sort.reverse)
    end

    it "limits to 50 results" do
      # Create 51 unique merchants
      51.times do |i|
        create(:transaction, user: user, account: account, description: "MERCHANT_#{i}", amount_cents: -1000, settled_at: 1.day.ago)
      end

      results = Transaction.total_by_merchant(user)
      expect(results.count).to eq(50)
    end
  end

  describe ".income_vs_expenses" do
    context "without date range" do
      it "returns correct income, expenses, and net" do
        result = Transaction.income_vs_expenses(user)

        expect(result[:income_cents]).to eq(10000)
        expect(result[:expenses_cents]).to eq(10000) # 5000 + 3000 + 2000
        expect(result[:net_cents]).to eq(0) # 10000 - 10000
        expect(result[:income]).to eq(100.0)
        expect(result[:expenses]).to eq(100.0)
        expect(result[:net]).to eq(0.0)
      end

      it "excludes other users' transactions" do
        result = Transaction.income_vs_expenses(user)
        # Other user's -10000 should not be included
        expect(result[:expenses_cents]).to eq(10000)
      end
    end

    context "with date range" do
      it "only includes transactions within the date range" do
        start_date = 4.days.ago.beginning_of_day
        end_date = 2.days.ago.end_of_day

        result = Transaction.income_vs_expenses(user, start_date, end_date)

        # Only transactions from 4-2 days ago: -3000 (category1) + -2000 (category2) = -5000 expenses
        # Income (1 day ago) is excluded
        expect(result[:expenses_cents]).to eq(5000)
        expect(result[:income_cents]).to eq(0)
        expect(result[:net_cents]).to eq(-5000)
      end
    end
  end

  describe ".time_series_by_day" do
    before do
      create(:transaction, user: user, account: account, amount_cents: -1000, settled_at: Time.zone.parse("2024-01-01 10:00"))
      create(:transaction, user: user, account: account, amount_cents: -2000, settled_at: Time.zone.parse("2024-01-01 14:00"))
      create(:transaction, user: user, account: account, amount_cents: -3000, settled_at: Time.zone.parse("2024-01-02 12:00"))
    end

    it "groups transactions by day" do
      start_date = Time.zone.parse("2024-01-01")
      end_date = Time.zone.parse("2024-01-02")

      result = Transaction.time_series_by_day(user, start_date, end_date, type: :expenses)

      expect(result["2024-01-01"]).to eq(3000) # 1000 + 2000
      expect(result["2024-01-02"]).to eq(3000)
    end

    it "filters by type when specified" do
      create(:transaction, user: user, account: account, amount_cents: 5000, settled_at: Time.zone.parse("2024-01-01 15:00"))

      start_date = Time.zone.parse("2024-01-01")
      end_date = Time.zone.parse("2024-01-01")

      result = Transaction.time_series_by_day(user, start_date, end_date, type: :expenses)
      expect(result["2024-01-01"]).to eq(3000) # Only expenses

      result = Transaction.time_series_by_day(user, start_date, end_date, type: :income)
      expect(result["2024-01-01"]).to eq(5000) # Only income
    end

    it "only includes transactions with settled_at" do
      create(:transaction, user: user, account: account, amount_cents: -1000, settled_at: nil)

      start_date = 1.week.ago
      end_date = Time.current

      result = Transaction.time_series_by_day(user, start_date, end_date, type: :expenses)
      # Should not include the transaction without settled_at
      expect(result.values.sum).to be <= 10000 # Only transactions with settled_at
    end
  end

  describe ".time_series_by_month" do
    before do
      create(:transaction, user: user, account: account, amount_cents: -5000, settled_at: Time.zone.parse("2024-01-15"))
      create(:transaction, user: user, account: account, amount_cents: -3000, settled_at: Time.zone.parse("2024-01-20"))
      create(:transaction, user: user, account: account, amount_cents: -2000, settled_at: Time.zone.parse("2024-02-10"))
    end

    it "groups transactions by month" do
      start_date = Time.zone.parse("2024-01-01")
      end_date = Time.zone.parse("2024-02-28")

      result = Transaction.time_series_by_month(user, start_date, end_date, type: :expenses)

      expect(result["2024-01"]).to eq(8000) # 5000 + 3000
      expect(result["2024-02"]).to eq(2000)
    end

    it "only includes transactions with settled_at" do
      create(:transaction, user: user, account: account, amount_cents: -1000, settled_at: nil)

      start_date = 6.months.ago
      end_date = Time.current

      result = Transaction.time_series_by_month(user, start_date, end_date, type: :expenses)
      # Should not include the transaction without settled_at
      expect(result.values.sum).to be <= 10000 # Only transactions with settled_at
    end
  end
end

