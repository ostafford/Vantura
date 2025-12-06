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

  describe ".spending_trend" do
    before do
      # Clear existing transactions from shared before block
      user.transactions.destroy_all

      # Current period transactions
      create(:transaction, user: user, account: account, amount_cents: -5000, settled_at: 5.days.ago)
      create(:transaction, user: user, account: account, amount_cents: -3000, settled_at: 3.days.ago)

      # Previous period transactions
      create(:transaction, user: user, account: account, amount_cents: -2000, settled_at: 35.days.ago)
      create(:transaction, user: user, account: account, amount_cents: -1000, settled_at: 32.days.ago)
    end

    it "compares spending between two periods" do
      current_start = 7.days.ago.beginning_of_day
      current_end = Time.current.end_of_day
      previous_start = 40.days.ago.beginning_of_day
      previous_end = 30.days.ago.end_of_day

      trend = Transaction.spending_trend(user, current_start, current_end, previous_start, previous_end, type: :expenses)

      expect(trend[:current_period_cents]).to eq(8000) # 5000 + 3000
      expect(trend[:previous_period_cents]).to eq(3000) # 2000 + 1000
      expect(trend[:difference_cents]).to eq(5000) # 8000 - 3000
      expect(trend[:trend]).to eq(:increasing)
      expect(trend[:percent_change]).to be > 0
    end

    it "calculates decreasing trend correctly" do
      current_start = 40.days.ago.beginning_of_day
      current_end = 30.days.ago.end_of_day
      previous_start = 7.days.ago.beginning_of_day
      previous_end = Time.current.end_of_day

      trend = Transaction.spending_trend(user, current_start, current_end, previous_start, previous_end, type: :expenses)

      expect(trend[:trend]).to eq(:decreasing)
      expect(trend[:percent_change]).to be < 0
    end

    it "works with income transactions" do
      user.transactions.destroy_all
      create(:transaction, user: user, account: account, amount_cents: 10000, settled_at: 5.days.ago)
      create(:transaction, user: user, account: account, amount_cents: 5000, settled_at: 35.days.ago)

      current_start = 7.days.ago.beginning_of_day
      current_end = Time.current.end_of_day
      previous_start = 40.days.ago.beginning_of_day
      previous_end = 30.days.ago.end_of_day

      trend = Transaction.spending_trend(user, current_start, current_end, previous_start, previous_end, type: :income)

      expect(trend[:current_period_cents]).to eq(10000)
      expect(trend[:previous_period_cents]).to eq(5000)
      expect(trend[:trend]).to eq(:increasing)
    end
  end

  describe ".category_comparison_over_time" do
    before do
      # Clear existing transactions for this test context
      user.transactions.destroy_all

      # Period 1 transactions
      create(:transaction, user: user, account: account, amount_cents: -5000, category: category1, settled_at: 35.days.ago)
      create(:transaction, user: user, account: account, amount_cents: -2000, category: category2, settled_at: 32.days.ago)

      # Period 2 transactions
      create(:transaction, user: user, account: account, amount_cents: -3000, category: category1, settled_at: 5.days.ago)
      create(:transaction, user: user, account: account, amount_cents: -4000, category: category2, settled_at: 3.days.ago)
    end

    it "compares categories across two periods" do
      period1_start = 40.days.ago.beginning_of_day
      period1_end = 30.days.ago.end_of_day
      period2_start = 7.days.ago.beginning_of_day
      period2_end = Time.current.end_of_day

      comparison = Transaction.category_comparison_over_time(
        user, period1_start, period1_end, period2_start, period2_end
      )

      groceries_comparison = comparison.find { |c| c[:category_name] == "Groceries" }
      expect(groceries_comparison[:period1_cents]).to eq(5000)
      expect(groceries_comparison[:period2_cents]).to eq(3000)
      expect(groceries_comparison[:trend]).to eq(:decreasing)

      entertainment_comparison = comparison.find { |c| c[:category_name] == "Entertainment" }
      expect(entertainment_comparison[:period1_cents]).to eq(2000)
      expect(entertainment_comparison[:period2_cents]).to eq(4000)
      expect(entertainment_comparison[:trend]).to eq(:increasing)
    end
  end

  describe ".merchant_trends" do
    before do
      create(:transaction, user: user, account: account, description: "NETFLIX SUBSCRIPTION", amount_cents: -1599, settled_at: 60.days.ago)
      create(:transaction, user: user, account: account, description: "NETFLIX PAYMENT", amount_cents: -1599, settled_at: 30.days.ago)
      create(:transaction, user: user, account: account, description: "NETFLIX.COM", amount_cents: -1599, settled_at: 5.days.ago)
    end

    it "analyzes merchant transaction trends" do
      start_date = 90.days.ago.beginning_of_day
      end_date = Time.current.end_of_day

      trends = Transaction.merchant_trends(user, "NETFLIX", start_date, end_date)

      expect(trends).not_to be_nil
      expect(trends[:merchant_name]).to eq("NETFLIX")
      expect(trends[:transaction_count]).to eq(3)
      expect(trends[:total_cents]).to eq(4797) # 1599 * 3
      expect(trends[:average_amount_cents]).to eq(1599)
      expect(trends[:first_transaction_date]).to be_present
      expect(trends[:last_transaction_date]).to be_present
    end

    it "calculates average frequency between transactions" do
      start_date = 90.days.ago.beginning_of_day
      end_date = Time.current.end_of_day

      trends = Transaction.merchant_trends(user, "NETFLIX", start_date, end_date)

      expect(trends[:average_frequency_days]).to be_present
      expect(trends[:average_frequency_days]).to be > 0
    end

    it "returns nil for non-existent merchant" do
      trends = Transaction.merchant_trends(user, "NONEXISTENT MERCHANT", 90.days.ago, Time.current)
      expect(trends).to be_nil
    end
  end

  describe ".monthly_spending_trends" do
    before do
      # Create transactions across multiple months
      create(:transaction, user: user, account: account, amount_cents: -5000, settled_at: 3.months.ago)
      create(:transaction, user: user, account: account, amount_cents: -3000, settled_at: 2.months.ago)
      create(:transaction, user: user, account: account, amount_cents: -4000, settled_at: 1.month.ago)
      create(:transaction, user: user, account: account, amount_cents: -6000, settled_at: 1.week.ago)
    end

    it "returns monthly spending trends with comparisons" do
      trends = Transaction.monthly_spending_trends(user, months_back: 6)

      expect(trends.length).to be >= 3
      expect(trends.first[:amount_cents]).to be > 0
      expect(trends.first).to have_key(:month)
      expect(trends.first).to have_key(:month_name)
    end

    it "includes trend information for months with previous data" do
      trends = Transaction.monthly_spending_trends(user, months_back: 6)

      # All but the first month should have trend data
      trends_with_trends = trends.select { |t| t.has_key?(:trend) }
      expect(trends_with_trends.length).to be >= 2
    end

    it "calculates percent change correctly" do
      trends = Transaction.monthly_spending_trends(user, months_back: 6)

      trend_with_change = trends.find { |t| t.has_key?(:percent_change) }
      expect(trend_with_change).to be_present
      expect(trend_with_change[:percent_change]).to be_a(Numeric)
    end
  end
end
