class TransactionsController < ApplicationController
  before_action :authenticate_user!

  def index
    @transactions = current_user.transactions
                                .includes(:account, :category)
                                .recent
    @pagy, @transactions = pagy(:offset, @transactions, items: 20)
  end

  def show
    @transaction = current_user.transactions.find(params[:id])
  end
end

