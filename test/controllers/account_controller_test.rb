require "test_helper"

class AccountControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    sign_in_as(:one)
  end

  test "should show account" do
    get account_url
    assert_response :success
    assert_select "h1", "Account"
  end

  test "should get edit" do
    get edit_account_url
    assert_response :success
    assert_select "h1", "Edit Account"
  end

  test "should update account with valid params" do
    # Ensure user has token if they have accounts (required by validation)
    if @user.accounts.any? && @user.up_bank_token.blank?
      @user.update_column(:up_bank_token, "test_token")
    end

    patch account_url, params: { user: { email_address: "newemail@example.com" } }
    assert_redirected_to account_url
    assert_match "updated successfully", flash[:notice]
    @user.reload
    assert_equal "newemail@example.com", @user.email_address
  end

  test "should not update account with invalid params" do
    # Ensure user has token if they have accounts (required by validation)
    if @user.accounts.any? && @user.up_bank_token.blank?
      @user.update_column(:up_bank_token, "test_token")
    end

    original_email = @user.email_address
    patch account_url, params: { user: { email_address: "invalid-email" } }
    assert_response :unprocessable_entity
    @user.reload
    assert_equal original_email, @user.email_address
  end

  test "should destroy account" do
    account_count = @user.accounts.count
    transaction_count = @user.accounts.joins(:transactions).count

    # Clean up associations that might cause issues
    @user.filters.destroy_all
    @user.owned_projects.destroy_all
    ProjectMembership.where(user: @user).destroy_all

    assert_difference("User.count", -1) do
      delete account_url
    end

    assert_redirected_to new_session_url
    assert_match "permanently deleted", flash[:notice]
  end

  test "requires authentication" do
    delete session_url
    delete account_url
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
    @user.filters.destroy_all
    @user.owned_projects.destroy_all
    ProjectMembership.where(user: @user).destroy_all

    account_count_before = @user.accounts.count

    assert_difference("Account.count", -account_count_before) do
      delete account_url
    end
  end
end
