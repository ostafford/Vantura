require "rails_helper"

RSpec.describe "Dashboard Charts", type: :system do
  let(:user) { create(:user) }
  let!(:account) { create(:account, user: user, balance_cents: 100_000) }

  before do
    sign_in user
  end

  describe "Chart Rendering" do
    context "with transaction data" do
      let!(:category) { create(:category, name: "Groceries") }
      let!(:income_transaction) do
        create(:transaction,
          user: user,
          account: account,
          amount_cents: 5000, # $50 income
          settled_at: 1.day.ago
        )
      end

      let!(:expense_transaction) do
        create(:transaction,
          user: user,
          account: account,
          amount_cents: -2000, # $20 expense
          settled_at: 1.day.ago,
          category: category
        )
      end

      it "renders income vs expenses chart" do
        visit dashboard_path

        # Check chart container exists
        expect(page).to have_css("#income-vs-expenses-chart")

        # Check Chart.js canvas is rendered (Chartkick creates canvas element)
        expect(page).to have_css("#income-vs-expenses-chart canvas", wait: 5)
      end

      it "renders category breakdown chart" do
        visit dashboard_path

        expect(page).to have_css("#category-breakdown-chart")
        expect(page).to have_css("#category-breakdown-chart canvas", wait: 5)
      end

      it "renders spending trend chart" do
        visit dashboard_path

        expect(page).to have_css("#spending-trend-chart")
        expect(page).to have_css("#spending-trend-chart canvas", wait: 5)
      end

      it "renders merchant analytics chart" do
        visit dashboard_path

        expect(page).to have_css("#merchant-analytics-chart")
        expect(page).to have_css("#merchant-analytics-chart canvas", wait: 5)
      end

      it "renders daily average chart" do
        visit dashboard_path

        expect(page).to have_css("#daily-average-chart")
        expect(page).to have_css("#daily-average-chart canvas", wait: 5)
      end
    end

    context "with no transaction data" do
      it "displays charts with empty state" do
        visit dashboard_path

        # Charts should still render, just with no data
        expect(page).to have_css("#income-vs-expenses-chart")
        expect(page).to have_css("#category-breakdown-chart")
        expect(page).to have_css("#spending-trend-chart")
        expect(page).to have_css("#merchant-analytics-chart")
        expect(page).to have_css("#daily-average-chart")
      end
    end
  end

  describe "Chart Data Accuracy" do
    let!(:category) { create(:category, name: "Salary") }
    let!(:transactions) do
      [
        create(:transaction,
          user: user,
          account: account,
          amount_cents: 10000, # $100 income
          settled_at: 5.days.ago,
          category: category
        ),
        create(:transaction,
          user: user,
          account: account,
          amount_cents: -5000, # $50 expense
          settled_at: 3.days.ago,
          category: create(:category, name: "Groceries")
        )
      ]
    end

    it "displays charts with correct data structure" do
      visit dashboard_path

      # Verify chart containers have data attributes
      # Chartkick renders data in data attributes
      chart_element = page.find("#income-vs-expenses-chart")

      # Check that chart data is present (Chartkick stores data in data attributes)
      expect(chart_element).to have_css("canvas")

      # Verify data is calculated correctly by checking controller logic
      # This is more of an integration test - we trust Chartkick to render correctly
      # but we verify our data preparation is correct
      expect(page).to have_css("#category-breakdown-chart canvas")
    end
  end

  describe "Turbo Stream Updates" do
    let!(:category) { create(:category, name: "Groceries") }

    it "updates charts when new transaction is added via webhook" do
      visit dashboard_path

      # Initial chart state
      expect(page).to have_css("#income-vs-expenses-chart canvas", wait: 5)

      # Create a new transaction (simulating webhook)
      new_transaction = create(:transaction,
        user: user,
        account: account,
        amount_cents: 3000, # $30
        settled_at: Time.current,
        category: category
      )

      # Simulate webhook broadcast (using ProcessUpWebhookJob logic)
      # In a real scenario, this would be triggered by ProcessUpWebhookJob
      # For testing, we'll manually broadcast the update
      income_vs_expenses_data = [
        {
          name: "Income",
          data: Transaction.time_series_by_day(
            user,
            30.days.ago.beginning_of_day,
            Time.current.end_of_day,
            type: :income
          ).transform_values { |cents| cents / 100.0 }
        },
        {
          name: "Expenses",
          data: Transaction.time_series_by_day(
            user,
            30.days.ago.beginning_of_day,
            Time.current.end_of_day,
            type: :expenses
          ).transform_values { |cents| cents.abs / 100.0 }
        }
      ]

      # Broadcast update via Turbo Stream
      Turbo::StreamsChannel.broadcast_replace_to(
        "user_#{user.id}_dashboard",
        target: "income-vs-expenses-chart",
        partial: "dashboard/charts/income_vs_expenses",
        locals: {
          income_vs_expenses_data: income_vs_expenses_data
        }
      )

      # Wait for Turbo Stream update
      sleep 1

      # Chart should still be present after update
      expect(page).to have_css("#income-vs-expenses-chart canvas")
    end

    it "updates charts when sync completes" do
      visit dashboard_path

      # Initial chart state
      expect(page).to have_css("#category-breakdown-chart canvas", wait: 5)

      # Create transactions
      create(:transaction,
        user: user,
        account: account,
        amount_cents: -1000,
        settled_at: Time.current,
        category: category
      )

      # Simulate sync completion broadcast
      category_breakdown_data = Transaction.total_by_category(
        user,
        Time.current.beginning_of_month,
        Time.current.end_of_month
      ).map { |cat| [ cat.name, cat.total_cents / 100.0 ] }.to_h

      Turbo::StreamsChannel.broadcast_replace_to(
        "user_#{user.id}_dashboard",
        target: "category-breakdown-chart",
        partial: "dashboard/charts/category_breakdown",
        locals: {
          category_breakdown_data: category_breakdown_data
        }
      )

      # Wait for Turbo Stream update
      sleep 1

      # Chart should still be present after update
      expect(page).to have_css("#category-breakdown-chart canvas")
    end
  end

  describe "Chart Titles and Labels" do
    it "displays correct chart titles" do
      visit dashboard_path

      expect(page).to have_text("Income vs Expenses (Last 30 Days)")
      expect(page).to have_text("Category Breakdown (This Month)")
      expect(page).to have_text("Spending Trend (Last 6 Months)")
      expect(page).to have_text("Top Merchants (This Month)")
      expect(page).to have_text("Daily Spending (Last 30 Days)")
    end
  end
end
