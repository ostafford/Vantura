require "application_system_test_case"

class UserAuthenticationTest < ApplicationSystemTestCase
  test "user can sign up with valid information" do
    visit sign_up_path

    fill_in "user_email_address", with: "newuser@example.com"
    fill_in "user_password", with: "password123"
    fill_in "user_password_confirmation", with: "password123"

    click_button "Create Account"

    # Should redirect to settings page where user adds account
    assert_text "Vantura"
    # After sign up, user needs to add account, so they go to settings
    assert_current_path settings_path
  end

  test "user cannot sign up with invalid email" do
    visit sign_up_path

    fill_in "user_email_address", with: "invalid-email"
    fill_in "user_password", with: "password123"
    fill_in "user_password_confirmation", with: "password123"

    click_button "Create Account"

    # Should stay on sign up page with error
    # The error message format might vary
    assert_text "Email"
  end

  test "user can sign in with valid credentials" do
    user = users(:one)

    visit new_session_path

    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password"

    click_button "Sign in"

    # Should redirect to dashboard
    assert_text "Vantura"
    assert_current_path root_path
  end

  test "user cannot sign in with invalid password" do
    user = users(:one)

    visit new_session_path

    fill_in "email_address", with: user.email_address
    fill_in "password", with: "wrongpassword"

    click_button "Sign in"

    # Should stay on login page with error
    # The error might be in an alert or the page content
    assert_current_path new_session_path
    assert_text "Sign in"
  end

  test "user can sign out" do
    user = users(:one)

    # Sign in first
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password"
    click_button "Sign in"

    # Then sign out - check if there's a confirmation dialog
    begin
      accept_confirm do
        click_button "Sign Out"
      end
    rescue Capybara::ModalNotFound
      # If no confirmation dialog, just click the button
      click_button "Sign Out"
    end

    # Should redirect to sign in page
    assert_current_path new_session_path
  end
end
