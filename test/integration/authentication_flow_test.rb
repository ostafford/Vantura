require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  test "complete sign up and sign in flow" do
    # Visit sign up page
    get sign_up_path
    assert_response :success
    assert_select "h1", "Create Account"

    # Submit sign up form
    post sign_up_path, params: {
      user: {
        email_address: "newuser@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    # Should redirect to settings (new user has no account yet)
    assert_redirected_to settings_path
    follow_redirect!
    assert_response :success
    assert_select "h1", "Settings"

    # Sign out
    delete session_path
    assert_redirected_to new_session_path

    # Sign in with new account
    post session_path, params: {
      email_address: "newuser@example.com",
      password: "password123"
    }

    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
  end

  test "failed login attempt" do
    user = users(:one)

    # Attempt login with wrong password
    post session_path, params: {
      email_address: user.email_address,
      password: "wrongpassword"
    }

    assert_redirected_to new_session_path
    follow_redirect!
    assert_select "div", text: /Try another email/
  end

  test "unauthenticated user redirected to sign in" do
    # Try to access dashboard without authentication
    get root_path

    assert_redirected_to new_session_path
  end

  test "authenticated user can access protected pages" do
    sign_in_as :one

    # Should access dashboard
    get root_path
    assert_response :success

    # Should access calendar
    get calendar_path
    assert_response :success

    # Should access settings
    get settings_path
    assert_response :success
  end
end
