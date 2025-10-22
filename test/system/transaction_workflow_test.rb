require "application_system_test_case"

class TransactionWorkflowTest < ApplicationSystemTestCase
  def setup
    @user = users(:one)
    @account = accounts(:one)
    sign_in_user(@user)
  end

  test "user can add hypothetical expense transaction", :js do
    visit root_path

    # Open transaction drawer (needs JS)
    find("button", text: "Add Transaction", match: :first).click

    # Wait for drawer to be visible
    assert_selector "#transactionModal", visible: true

    # Fill in transaction details
    fill_in "What are you buying?", with: "Test Laptop Purchase"
    fill_in "How much will it cost?", with: "1500"
    fill_in "When do you plan to buy it?", with: Date.today.to_s

    # Submit form
    click_button "Add Transaction"

    # Should see success message (via Turbo Stream or redirect)
    # Note: This might need adjustment based on your Turbo Stream implementation
  end

  test "user can view all transactions" do
    visit root_path

    click_link "View All"

    # Should be on all transactions page
    assert_text "All Transactions"
    assert_selector "table"
  end

  test "user can filter expenses" do
    visit transactions_all_path

    # Click expenses filter (if available)
    # This test assumes filter UI exists
    # Adjust based on your actual UI
  end

  test "user can navigate to calendar" do
    visit root_path

    # Find and click calendar link
    find('a[href*="calendar"]', match: :first).click

    assert_text "Vantura Calendar"
  end

  private

  def sign_in_user(user)
    visit new_session_path
    fill_in "Email Address", with: user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
  end
end
