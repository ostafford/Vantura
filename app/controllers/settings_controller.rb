class SettingsController < ApplicationController
  include Settings::Profile
  include Settings::Integrations::UpBank

  def show
    @user = Current.user
    @accounts_count = @user.accounts.count
    @projects_count = user_projects_count
  end

  def update_profile
    update_user_profile
  end

  def update_up_bank_integration
    update_up_bank_token
  end

  def destroy
    # Delete the user and all associated data
    user = Current.user

    # Log the deletion for audit purposes
    Rails.logger.info "User #{user.id} (#{user.email_address}) requested account deletion"

    # Count data for confirmation message
    accounts_count = user.accounts.count
    transactions_count = user.accounts.joins(:transactions).count

    # Destroy user (cascades to sessions, accounts, transactions, recurring transactions)
    user.destroy!

    # Terminate session (user is already gone)
    cookies.delete(:session_id)

    # Log successful deletion
    Rails.logger.info "User account deleted: #{accounts_count} accounts, #{transactions_count} transactions removed"

    redirect_to new_session_path, notice: "Your account and all associated data have been permanently deleted. Thank you for using Vantura."
  end

  private

  def user_projects_count
    Project
      .joins("LEFT JOIN project_memberships ON project_memberships.project_id = projects.id")
      .where("projects.owner_id = :uid OR project_memberships.user_id = :uid", uid: Current.user.id)
      .distinct
      .count
  end
end
