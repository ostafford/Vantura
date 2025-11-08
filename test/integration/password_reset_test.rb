require "test_helper"

class PasswordResetTest < ActionDispatch::IntegrationTest
  test "complete password reset flow" do
    user = users(:one)
    old_password = "password"
    new_password = "newpassword123"

    # Ensure user has up_bank_token if they have accounts (required by validation)
    if user.accounts.any? && user.up_bank_token.blank?
      user.update_column(:up_bank_token, "test_token")
    end

    # Step 1: Request password reset
    post passwords_path, params: { email_address: user.email_address }
    assert_redirected_to new_session_path
    follow_redirect!
    assert_match /Password reset instructions sent/, response.body

    # Step 2: Get password reset token
    user.reload
    token = user.password_reset_token
    assert_not_nil token, "Password reset token should be generated"

    # Step 3: Access password reset edit page with valid token
    get edit_password_path(token)
    assert_response :success
    assert_select "h1", "Update Password"

    # Step 4: Submit new password
    put password_path(token), params: {
      user: {
        password: new_password,
        password_confirmation: new_password
      }
    }
    assert_redirected_to new_session_path
    follow_redirect!
    assert_match /Password has been reset/, response.body

    # Step 5: Verify old password no longer works
    post session_path, params: {
      email_address: user.email_address,
      password: old_password
    }
    assert_redirected_to new_session_path
    follow_redirect!
    assert_match /Try another email/, response.body

    # Step 6: Verify new password works
    post session_path, params: {
      email_address: user.email_address,
      password: new_password
    }
    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
  end

  test "password reset with mismatched confirmation fails" do
    user = users(:one)
    new_password = "newpassword123"

    # Ensure user has up_bank_token if they have accounts (required by validation)
    if user.accounts.any? && user.up_bank_token.blank?
      user.update_column(:up_bank_token, "test_token")
    end

    # Request password reset
    post passwords_path, params: { email_address: user.email_address }
    user.reload
    token = user.password_reset_token

    # Try to submit with mismatched passwords
    put password_path(token), params: {
      user: {
        password: new_password,
        password_confirmation: "differentpassword"
      }
    }
    assert_response :unprocessable_entity
    assert_select "div", text: /error/i
  end

  test "password reset with password too short fails" do
    user = users(:one)
    short_password = "short"

    # Ensure user has up_bank_token if they have accounts (required by validation)
    if user.accounts.any? && user.up_bank_token.blank?
      user.update_column(:up_bank_token, "test_token")
    end

    # Request password reset
    post passwords_path, params: { email_address: user.email_address }
    user.reload
    token = user.password_reset_token

    # Try to submit with password too short
    put password_path(token), params: {
      user: {
        password: short_password,
        password_confirmation: short_password
      }
    }
    assert_response :unprocessable_entity
    assert_select "div", text: /too short/i
  end

  test "password reset with invalid token fails" do
    invalid_token = "invalid_token_12345"

    # Try to access password reset page with invalid token
    get edit_password_path(invalid_token)
    assert_redirected_to new_password_path
    follow_redirect!
    assert_match /invalid or has expired/, response.body
  end

  test "password reset request for non-existent email still shows success message" do
    # Request password reset for non-existent email
    post passwords_path, params: { email_address: "nonexistent@example.com" }
    assert_redirected_to new_session_path
    follow_redirect!
    # Should still show success message (security best practice)
    assert_match /Password reset instructions sent/, response.body
  end
end
