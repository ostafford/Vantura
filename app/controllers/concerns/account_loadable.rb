module AccountLoadable
  extend ActiveSupport::Concern

  private

  # Load the account for the current user and handle the case where no account exists
  # Sets @account instance variable
  # Redirects to settings if no account found (user needs to configure token)
  def load_account
    # Don't override if account was already set (e.g., by authorize_account_ownership!)
    return true if @account

    @account = Current.user.accounts.order(:created_at).last

    unless @account
      redirect_to settings_path, alert: "Please configure your Up Bank token first."
      return false
    end

    true
  end

  # Load account and return early if not found (for actions that should silently return)
  def load_account_or_return
    @account = Current.user.accounts.order(:created_at).last
  end

  # Verify that the account_id parameter belongs to the current user
  # Returns 403 Forbidden if account doesn't belong to user
  def authorize_account_ownership!
    return unless params[:account_id].present?

    account = Current.user.accounts.find_by(id: params[:account_id])
    unless account
      head :forbidden
      return false
    end

    @account = account
    true
  end
end
