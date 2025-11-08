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
    # Verify deletion token is generated in session
    assert_not_nil session[:deletion_token]
    assert_equal 32, session[:deletion_token].length # SecureRandom.hex(16) = 32 chars
    # Verify @statistics is set
    assert_not_nil assigns(:statistics)
    assert_not_nil assigns(:statistics)[:accounts_count]
    assert_not_nil assigns(:statistics)[:projects_count]
  end

  test "should update profile with valid params" do
    # Ensure user has token if they have accounts (required by validation)
    if @user.accounts.any? && @user.up_bank_token.blank?
      @user.update_column(:up_bank_token, "test_token")
    end

    # Test HTML format (fallback)
    patch update_profile_settings_url, params: { user: { email_address: "newemail@example.com" } }
    assert_redirected_to settings_url
    assert_match "updated successfully", flash[:notice]
    @user.reload
    assert_equal "newemail@example.com", @user.email_address
  end

  test "should update profile with Turbo Stream format" do
    # Ensure user has token if they have accounts (required by validation)
    if @user.accounts.any? && @user.up_bank_token.blank?
      @user.update_column(:up_bank_token, "test_token")
    end

    patch update_profile_settings_url, params: { user: { email_address: "turbo@example.com" } }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.content_type
    @user.reload
    assert_equal "turbo@example.com", @user.email_address
    # Verify @statistics is set for Turbo Stream response
    assert_not_nil assigns(:statistics)
  end

  test "should not update profile with invalid params" do
    # Ensure user has token if they have accounts (required by validation)
    if @user.accounts.any? && @user.up_bank_token.blank?
      @user.update_column(:up_bank_token, "test_token")
    end

    original_email = @user.email_address
    # Test HTML format
    patch update_profile_settings_url, params: { user: { email_address: "invalid-email" } }
    assert_response :unprocessable_entity
    @user.reload
    assert_equal original_email, @user.email_address

    # Test Turbo Stream format
    patch update_profile_settings_url, params: { user: { email_address: "invalid-email" } }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.content_type
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

  test "should destroy account with valid token" do
    # Get deletion token from show action
    get settings_url
    deletion_token = session[:deletion_token]
    assert_not_nil deletion_token

    account_count = @user.accounts.count
    transaction_count = @user.accounts.joins(:transactions).count

    # Clean up associations that might cause issues
    @user.owned_projects.destroy_all
    ProjectMembership.where(user: @user).destroy_all

    # Test HTML format (fallback)
    assert_difference("User.count", -1) do
      delete settings_url, params: { confirmation_token: deletion_token }
    end

    assert_redirected_to new_session_url
    assert_match "permanently deleted", flash[:notice]
  end

  test "should destroy account with valid token via Turbo Stream" do
    # Get deletion token from show action
    get settings_url
    deletion_token = session[:deletion_token]
    assert_not_nil deletion_token

    # Clean up associations that might cause issues
    @user.owned_projects.destroy_all
    ProjectMembership.where(user: @user).destroy_all

    # Test Turbo Stream format
    assert_difference("User.count", -1) do
      delete settings_url, params: { confirmation_token: deletion_token }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.content_type
    # Verify @deletion_result is set
    assert_not_nil assigns(:deletion_result)
    assert assigns(:deletion_result)[:success]
  end

  test "should not destroy account without token" do
    account_count_before = @user.accounts.count

    # Test HTML format
    assert_no_difference("User.count") do
      delete settings_url
    end

    assert_redirected_to settings_url
    assert_match "Invalid confirmation token", flash[:alert]

    # Test Turbo Stream format
    assert_no_difference("User.count") do
      delete settings_url, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.content_type
    assert_not_nil assigns(:deletion_result)
    assert_not assigns(:deletion_result)[:success]
  end

  test "should not destroy account with invalid token" do
    # Get valid token
    get settings_url
    valid_token = session[:deletion_token]

    account_count_before = @user.accounts.count

    # Test HTML format
    assert_no_difference("User.count") do
      delete settings_url, params: { confirmation_token: "invalid_token_123" }
    end

    assert_redirected_to settings_url
    assert_match "Invalid confirmation token", flash[:alert]

    # Test Turbo Stream format
    assert_no_difference("User.count") do
      delete settings_url, params: { confirmation_token: "invalid_token_123" }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.content_type
    assert_not_nil assigns(:deletion_result)
    assert_not assigns(:deletion_result)[:success]
  end

  test "requires authentication" do
    delete session_url
    delete settings_url
    assert_redirected_to new_session_url
  end

  test "deletes associated data" do
    # Get deletion token
    get settings_url
    deletion_token = session[:deletion_token]

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
      delete settings_url, params: { confirmation_token: deletion_token }
    end
  end
end
