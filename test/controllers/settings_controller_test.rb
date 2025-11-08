require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    sign_in_as(:one)
  end

  test "should show settings" do
    get settings_url
    assert_response :success
    assert_select "h1", "Settings"
  end

  test "should update profile with valid params" do
    # Ensure user has token if they have accounts (required by validation)
    if @user.accounts.any? && @user.up_bank_token.blank?
      @user.update_column(:up_bank_token, "test_token")
    end

    patch update_profile_settings_url, params: { user: { email_address: "newemail@example.com" } }
    assert_redirected_to settings_url
    assert_match "updated successfully", flash[:notice]
    @user.reload
    assert_equal "newemail@example.com", @user.email_address
  end

  test "should not update profile with invalid params" do
    # Ensure user has token if they have accounts (required by validation)
    if @user.accounts.any? && @user.up_bank_token.blank?
      @user.update_column(:up_bank_token, "test_token")
    end

    original_email = @user.email_address
    patch update_profile_settings_url, params: { user: { email_address: "invalid-email" } }
    assert_response :unprocessable_entity
    @user.reload
    assert_equal original_email, @user.email_address
  end

  test "should reject empty up bank token" do
    patch update_up_bank_integration_settings_url, params: { user: { up_bank_token: "" } }
    assert_redirected_to settings_url
    assert_match "valid", flash[:alert]
  end

  test "should reject placeholder dots as token" do
    patch update_up_bank_integration_settings_url, params: { user: { up_bank_token: "••••••" } }
    assert_redirected_to settings_url
    assert_match "valid", flash[:alert]
  end

  test "should destroy account" do
    account_count = @user.accounts.count
    transaction_count = @user.accounts.joins(:transactions).count

    # Clean up associations that might cause issues
    @user.owned_projects.destroy_all
    ProjectMembership.where(user: @user).destroy_all

    assert_difference("User.count", -1) do
      delete settings_url
    end

    assert_redirected_to new_session_url
    assert_match "permanently deleted", flash[:notice]
  end

  test "requires authentication" do
    delete session_url
    delete settings_url
    assert_redirected_to new_session_url
  end

  test "deletes associated data" do
    @user.accounts.create!(
      up_account_id: "test_account",
      display_name: "Test Account",
      account_type: "TRANSACTIONAL",
      current_balance: 1000.0
    )

    # Clean up all associations to avoid constraint issues
    @user.owned_projects.destroy_all
    ProjectMembership.where(user: @user).destroy_all

    account_count_before = @user.accounts.count

    assert_difference("Account.count", -account_count_before) do
      delete settings_url
    end
  end
end
