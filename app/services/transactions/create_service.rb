class Transactions::CreateService < ApplicationService
  Result = Struct.new(:success?, :transaction, :errors)

  def initialize(account:, params:, transaction_type: nil)
    @account = account
    @params = params
    @transaction_type = transaction_type
  end

  def call
    transaction = @account.transactions.build(@params)
    transaction.is_hypothetical = true
    transaction.status = :hypothetical

    apply_sign!(transaction)

    if transaction.save
      Result.new(true, transaction, nil)
    else
      Result.new(false, transaction, transaction.errors)
    end
  end

  private

  def apply_sign!(transaction)
    type = @transaction_type
    # fallback from params if not explicitly provided
    if type.nil? && @params.respond_to?(:[]) && @params[:transaction_type]
      type = @params[:transaction_type]
    end

    if type == "expense"
      transaction.amount = -transaction.amount.abs if transaction.amount
    else
      transaction.amount = transaction.amount.abs if transaction.amount
    end
  end
end


