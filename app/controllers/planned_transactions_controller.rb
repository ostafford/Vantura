class PlannedTransactionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_planned_transaction, only: [ :show, :edit, :update, :destroy ]

  def index
    @planned_transactions = policy_scope(PlannedTransaction)
                                       .includes(:category, :transaction_record)
                                       .order(planned_date: :asc, created_at: :desc)
  end

  def show
    authorize @planned_transaction
  end

  def new
    @planned_transaction = current_user.planned_transactions.build
    @planned_transaction.planned_date = Date.current
    @planned_transaction.transaction_type = "expense"
    authorize @planned_transaction
  end

  def create
    @planned_transaction = current_user.planned_transactions.build(planned_transaction_params)
    authorize @planned_transaction

    if @planned_transaction.save
      redirect_to @planned_transaction, notice: I18n.t("flash.planned_transactions.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @planned_transaction
  end

  def update
    authorize @planned_transaction
    if @planned_transaction.update(planned_transaction_params)
      redirect_to @planned_transaction, notice: I18n.t("flash.planned_transactions.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @planned_transaction
    @planned_transaction.destroy
    redirect_to planned_transactions_path, notice: I18n.t("flash.planned_transactions.deleted")
  end

  private

  def set_planned_transaction
    @planned_transaction = current_user.planned_transactions.find(params[:id])
  end

  def planned_transaction_params
    params.require(:planned_transaction).permit(
      :name,
      :description,
      :amount_cents,
      :amount_currency,
      :planned_date,
      :transaction_type,
      :category_id,
      :is_recurring,
      :recurrence_pattern,
      :recurrence_rule,
      :recurrence_end_date,
      :transaction_id
    )
  end
end
