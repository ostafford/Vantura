# Service Object: Handle account deletion with token validation
#
# Usage:
#   result = AccountDeletionService.call(user, confirmation_token, session_token)
#
# Returns hash with:
#   - success: Boolean indicating if deletion was successful
#   - message: Success or error message
#   - accounts_count: Number of accounts deleted (if successful)
#   - transactions_count: Number of transactions deleted (if successful)
#
class AccountDeletionService < ApplicationService
  def initialize(user, confirmation_token, session_token)
    @user = user
    @confirmation_token = confirmation_token
    @session_token = session_token
  end

  def call
    return invalid_token_result unless valid_token?

    delete_user_account
  end

  private

  def valid_token?
    @confirmation_token.present? && @confirmation_token == @session_token
  end

  def invalid_token_result
    {
      success: false,
      message: "Invalid confirmation token. Please try again."
    }
  end

  def delete_user_account
    # Log the deletion for audit purposes
    Rails.logger.info "User #{@user.id} (#{@user.email_address}) requested account deletion"

    # Count data for confirmation message
    accounts_count = @user.accounts.count
    transactions_count = @user.accounts.joins(:transactions).count

    # Destroy user (cascades to sessions, accounts, transactions, recurring transactions)
    @user.destroy!

    # Log successful deletion
    Rails.logger.info "User account deleted: #{accounts_count} accounts, #{transactions_count} transactions removed"

    {
      success: true,
      message: "Your account and all associated data have been permanently deleted. Thank you for using Vantura.",
      accounts_count: accounts_count,
      transactions_count: transactions_count
    }
  rescue StandardError => e
    Rails.logger.error "Account deletion failed for user #{@user.id}: #{e.message}"
    {
      success: false,
      message: "An error occurred while deleting your account. Please try again or contact support."
    }
  end
end
