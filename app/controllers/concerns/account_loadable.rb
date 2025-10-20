module AccountLoadable
  extend ActiveSupport::Concern

  private

  # Load the account and handle the case where no account exists
  # Sets @account instance variable
  # Redirects to root with alert if no account found
  def load_account
    @account = Account.order(:created_at).last

    unless @account
      redirect_to root_path, alert: "No account found"
      return false
    end

    # Reload account to ensure we have fresh transaction data
    @account.reload
    true
  end

  # Load account and return early if not found (for actions that should silently return)
  def load_account_or_return
    @account = Account.order(:created_at).last
    return unless @account

    # Reload account to ensure we have fresh transaction data
    @account.reload
  end
end

