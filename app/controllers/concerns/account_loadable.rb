module AccountLoadable
  extend ActiveSupport::Concern

  private

  # Load the account for the current user and handle the case where no account exists
  # Sets @account instance variable
  # Redirects to settings if no account found (user needs to configure token)
  def load_account
    @account = Current.user.accounts.order(:created_at).last

    unless @account
      redirect_to settings_path, alert: "Please configure your Up Bank token first."
      return false
    end

    # Reload account to ensure we have fresh transaction data
    @account.reload
    true
  end

  # Load account and return early if not found (for actions that should silently return)
  def load_account_or_return
    @account = Current.user.accounts.order(:created_at).last
    return unless @account

    # Reload account to ensure we have fresh transaction data
    @account.reload
  end
end
