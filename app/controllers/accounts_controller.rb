class AccountsController < ApplicationController
  def index
    @accounts = current_user.accounts.order(:account_type)
  end

  def show
    @account = current_user.accounts.find(params[:id])
  end
end

