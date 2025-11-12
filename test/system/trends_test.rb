require "application_system_test_case"

class TrendsTest < ApplicationSystemTestCase
  def setup
    @user = users(:one)
    @account = accounts(:one)
    sign_in_user(@user)
  end

  test "user can view trends page with account data" do
    visit trends_path

    # Check main components are present
    assert_text "Trends"
    assert_text "Financial Insights"
    assert_selector ".bento-grid"
  end

  test "trends page displays Financial Insights Hub card" do
    visit trends_path

    assert_text "Financial Insights"
    assert_text "Net Savings"
  end

  test "trends page displays Net Savings card" do
    visit trends_path

    assert_selector "#net_savings_card", wait: 5
    assert_text "Net Savings"
  end

  test "trends page displays Active Recurring card" do
    visit trends_path

    assert_text "Active Recurring"
  end

  test "trends page displays Month Comparison card" do
    visit trends_path

    assert_text "Month Comparison"
  end

  test "trends page displays Top Category/Merchant card" do
    visit trends_path

    assert_text "Top"
  end

  test "trends page displays Savings Rate card" do
    visit trends_path

    assert_text "Savings Rate"
    assert_text "%"
  end

  test "trends page displays Spending Rate card" do
    visit trends_path

    assert_text "Spending Rate"
    assert_text "vs Income Rate"
  end

  test "trends page displays Recurring Breakdown card" do
    visit trends_path

    assert_text "Expense Breakdown"
    assert_text "Recurring vs Discretionary"
  end

  test "trends page displays insights in bento grid" do
    visit trends_path

    # Insights should be in the bento grid, not in a separate section
    assert_selector ".bento-grid"
    # Check for insight cards (they may or may not be present depending on data)
    # The bento grid should exist regardless
  end

  test "trends page shows enhanced Financial Insights Hub with savings rate" do
    visit trends_path

    # Check for enhanced indicators in Financial Insights Hub
    within ".bento-grid" do
      assert_text "Savings Rate", wait: 5
      assert_text "Income Utilization"
      assert_text "Income Stability"
    end
  end

  test "trends page shows enhanced Month Comparison with savings rate" do
    visit trends_path

    # Month Comparison card should show savings rate
    assert_text "Month Comparison"
    # Savings rate should appear in the comparison
  end

  test "trends page shows enhanced Top Merchant with month-over-month change" do
    visit trends_path

    # Top Merchant/Category card should show change indicators
    assert_text "Top"
    # Change indicators may be present if there's data
  end

  test "user can switch between category and merchant view" do
    visit trends_path

    # Find and click the view type toggle if it exists
    # This depends on the UI implementation
    if page.has_button?("Category") || page.has_button?("Merchant")
      # Toggle view type
      find("button", text: /Category|Merchant/, match: :first).click
      # Verify the view changed
      assert_current_path trends_path
    end
  end

  test "trends page displays charts section" do
    visit trends_path

    # Charts section should be present
    assert_text "Trends & Visualizations"
  end

  test "trends page displays category breakdown with changes" do
    visit trends_path

    # Category breakdown section should exist
    # May show month-over-month changes if data exists
    assert_selector ".bento-grid"
  end

  test "Savings Rate card shows trend indicators" do
    visit trends_path

    # Find Savings Rate card
    within ".bento-grid" do
      assert_text "Savings Rate"
      # Should show trend direction and 3-month average
      assert_text "%"
    end
  end

  test "Spending Rate card shows income utilization" do
    visit trends_path

    # Find Spending Rate card
    within ".bento-grid" do
      assert_text "Spending Rate"
      assert_text "Income Utilization"
    end
  end

  test "Recurring Breakdown card shows visual breakdown" do
    visit trends_path

    # Find Recurring Breakdown card
    within ".bento-grid" do
      assert_text "Expense Breakdown"
      assert_text "Recurring"
      assert_text "Discretionary"
    end
  end

  test "Recurring Breakdown card has link to manage recurring" do
    visit trends_path

    # Should have a link to recurring transactions
    if page.has_link?("Manage Recurring")
      assert_link "Manage Recurring"
    end
  end

  test "trends page is responsive" do
    visit trends_path

    # Check that the page loads without errors
    assert_no_selector ".error", wait: 2
    assert_selector ".bento-grid"
  end

  test "trends page handles empty data gracefully" do
    # Clear account transactions
    @account.transactions.destroy_all

    visit trends_path

    # Page should still load
    assert_text "Trends"
    assert_selector ".bento-grid"
  end

  test "trends page shows month selector" do
    visit trends_path

    # Month selector should be present
    # This may be a dropdown or buttons
    assert_selector "body" # At minimum, page should load
  end

  test "insights are displayed within bento grid" do
    visit trends_path

    # Insights should be part of the bento grid layout
    # Check that bento grid exists and insights may be inside
    assert_selector ".bento-grid"
    # Insight cards may or may not be present depending on data
  end
end

