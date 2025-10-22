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
    assert_selector "#projection_card"
  end

  test "user can navigate to settings" do
    visit root_path

    click_on "Settings"

    assert_current_path settings_path
    assert_text "Up Bank Integration"
  end

  test "user can navigate to calendar" do
    visit root_path

    click_link href: calendar_path

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
    fill_in "Email Address", with: new_user.email_address
    fill_in "Password", with: "password123"
    click_button "Sign in"

    # Should see setup guidance
    assert_text "Welcome to Vantura!"
    assert_text "Go to Settings"
  end

  private

  def sign_in_user(user)
    visit new_session_path
    fill_in "Email Address", with: user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
  end
end
