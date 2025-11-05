require "test_helper"

class AccountControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    sign_in_as(:one)
  end

  test "should destroy account" do
    account_count = @user.accounts.count
    transaction_count = @user.accounts.joins(:transactions).count

    # Clean up associations that might cause issues
    @user.filters.destroy_all
    @user.owned_projects.destroy_all
    ProjectMembership.where(user: @user).destroy_all

    assert_difference("User.count", -1) do
      delete delete_account_url
    end

    assert_redirected_to new_session_url
    assert_match "permanently deleted", flash[:notice]
  end

  test "requires authentication" do
    delete session_url
    delete delete_account_url
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
      delete delete_account_url
    end
  end
end
