require "application_system_test_case"

class UserAuthenticationTest < ApplicationSystemTestCase
  test "user can sign up with valid information" do
    visit sign_up_path

    fill_in "Email Address", with: "newuser@example.com"
    fill_in "Password", with: "password123"
    fill_in "Confirm Password", with: "password123"

    click_button "Create Account"

    # Should redirect to dashboard with welcome message
    assert_text "Vantura"
    assert_current_path root_path
  end

  test "user cannot sign up with invalid email" do
    visit sign_up_path

    fill_in "Email Address", with: "invalid-email"
    fill_in "Password", with: "password123"
    fill_in "Confirm Password", with: "password123"

    click_button "Create Account"

    # Should stay on sign up page with error
    assert_text "Email address is invalid"
  end

  test "user can sign in with valid credentials" do
    user = users(:one)

    visit new_session_path

    fill_in "Email Address", with: user.email_address
    fill_in "Password", with: "password"

    click_button "Sign in"

    # Should redirect to dashboard
    assert_text "Vantura"
    assert_current_path root_path
  end

  test "user cannot sign in with invalid password" do
    user = users(:one)

    visit new_session_path

    fill_in "Email Address", with: user.email_address
    fill_in "Password", with: "wrongpassword"

    click_button "Sign in"

    # Should stay on login page with error
    assert_text "Try another email address or password"
    assert_current_path new_session_path
  end

  test "user can sign out" do
    user = users(:one)

    # Sign in first
    visit new_session_path
    fill_in "Email Address", with: user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"

    # Then sign out
    accept_confirm do
      click_button "Sign Out"
    end

    # Should redirect to sign in page
    assert_current_path new_session_path
  end
end
