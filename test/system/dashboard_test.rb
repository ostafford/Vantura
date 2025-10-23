require "application_system_test_case"

class DashboardTest < ApplicationSystemTestCase
  def setup
    @user = users(:one)
    @account = accounts(:one)
    sign_in_user(@user)
  end

  test "user can view dashboard with account data" do
    visit root_path

    # Check main components are present
    assert_text "Vantura"
    assert_text "Current Balance"
    assert_text @account.display_name
    assert_selector "#expenses_card"
    assert_selector "#income_card"
    # projection_card might not exist if there's no data
    assert_text "End of Month Projection"
  end

  test "user can navigate to settings" do
    visit root_path

    click_on "Settings"

    assert_current_path settings_path
    assert_text "Up Bank Integration"
  end

  test "user can navigate to calendar" do
    visit root_path

    # Use first match since there might be multiple calendar links
    find("a[href='/calendar']", match: :first).click

    assert_text "Vantura Calendar"
  end

  test "dashboard shows recent transactions" do
    visit root_path

    # Should show Recent Transactions section
    assert_text "Recent Transactions"
  end

  test "user without account sees setup guide" do
    # Create user with no account
    new_user = User.create!(
      email_address: "noaccountuser@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    # Sign in as the new user
    visit new_session_path
    fill_in "email_address", with: new_user.email_address
    fill_in "password", with: "password123"
    click_button "Sign in"

    # User without account goes to root and sees welcome message
    assert_current_path root_path
    assert_text "Welcome to Vantura!"
  end

  private

  def sign_in_user(user)
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password"
    click_button "Sign in"

    # Wait for sign-in to complete
    assert_current_path root_path
  end
end
