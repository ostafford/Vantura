class RecurringTransactionsController < ApplicationController
  include AccountLoadable

  before_action :authorize_account_ownership!, only: [ :index ]
  before_action :load_account, except: [ :create, :suggest_frequency, :available_categories ]
  before_action :set_recurring_transaction, only: [ :edit, :update, :destroy, :toggle_active ]

  def index
    return unless load_account

    @recurring_transactions = @account.recurring_transactions.order(created_at: :desc)
    
    # Filter by category if provided
    if params[:category].present?
      @recurring_transactions = @recurring_transactions.where(recurring_category: params[:category])
    end
    
    @breakdown = RecurringTransactions::BreakdownService.call(@account)
  end

  def edit
    # Recurring transaction is already loaded by before_action
  end

  def update
    params_hash = recurring_transaction_params.to_h
    
    # Handle custom category creation if "other" is selected
    if params_hash["recurring_category"] == "other" && params[:custom_category_name].present?
      custom_category = @account.recurring_categories.find_or_create_by(
        name: params[:custom_category_name].strip,
        transaction_type: @recurring.transaction_type
      )
      
      if custom_category.persisted?
        params_hash["recurring_category"] = custom_category.name
      else
        @recurring.errors.add(:recurring_category, "Error creating custom category: #{custom_category.errors.full_messages.join(', ')}")
        render :edit, status: :unprocessable_entity
        return
      end
    end
    
    if @recurring.update(params_hash)
      redirect_to recurring_transactions_path(account_id: @account.id), notice: "Recurring transaction updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def create
    @transaction = Transaction.find(params[:transaction_id])
    @account = @transaction.account

    # Handle custom category creation if "other" is selected
    recurring_category = params[:recurring_category]
    custom_category_name = params[:custom_category_name]
    
    if recurring_category == "other" && custom_category_name.present?
      # Create or find custom category
      custom_category = @account.recurring_categories.find_or_create_by(
        name: custom_category_name.strip,
        transaction_type: @transaction.transaction_type
      )
      
      if custom_category.persisted?
        recurring_category = custom_category.name
      else
        redirect_back(
          fallback_location: root_path,
          alert: "Error creating custom category: #{custom_category.errors.full_messages.join(', ')}"
        )
        return
      end
    end

    # Create recurring transaction based on the selected transaction
    @recurring = @account.recurring_transactions.new(
      template_transaction_id: @transaction.id,
      description: @transaction.description,
      amount: @transaction.amount,
      category: @transaction.category,
      merchant_pattern: RecurringTransaction.extract_merchant_pattern(@transaction.description),
      amount_tolerance: params[:amount_tolerance] || 5.0,
      date_tolerance_days: params[:date_tolerance_days] || 3,
      tolerance_type: params[:tolerance_type] || "fixed",
      tolerance_percentage: params[:tolerance_percentage],
      frequency: params[:frequency],
      next_occurrence_date: params[:next_occurrence_date],
      transaction_type: @transaction.transaction_type,
      recurring_category: recurring_category,
      projection_months: params[:projection_months] || "indefinite",
      is_active: true
    )

    if @recurring.save
      # Generate future hypothetical transactions
      months_ahead = @recurring.projection_months == "indefinite" ? 12 : @recurring.projection_months.to_i
      RecurringTransactions::GenerateService.call(@recurring, months_ahead: months_ahead)

      redirect_back(
        fallback_location: root_path,
        notice: "Recurring transaction created! Future occurrences have been added to your calendar."
      )
    else
      redirect_back(
        fallback_location: root_path,
        alert: "Error creating recurring transaction: #{@recurring.errors.full_messages.join(', ')}"
      )
    end
  end

  def suggest_frequency
    @transaction = Transaction.find(params[:transaction_id])
    @account = @transaction.account

    result = RecurringTransactions::FrequencyDetectionService.call(@account, @transaction)

    render json: result
  end

  def available_categories
    # Get transaction type from either transaction_id or direct param
    if params[:transaction_id].present?
      @transaction = Transaction.find(params[:transaction_id])
      @account = @transaction.account
      transaction_type = @transaction.transaction_type
    elsif params[:transaction_type].present?
      # For cases where we only have the type (e.g., from JavaScript)
      transaction_type = params[:transaction_type]
      # Need account - try to get from Current.user's default account or require account_id
      @account = Current.user&.accounts&.first
      return head :bad_request unless @account
    else
      return head :bad_request
    end

    # Get available categories (predefined + custom)
    predefined = RecurringCategory.predefined_for_type(transaction_type)
    custom = @account.recurring_categories.for_transaction_type(transaction_type).pluck(:name)
    @categories = (predefined + custom).uniq.sort_by(&:downcase)
    @transaction_type = transaction_type

    render partial: "recurring_transactions/category_options"
  end

  def destroy
    # Delete all generated hypothetical transactions
    @recurring.generated_transactions.hypothetical.destroy_all

    # Delete the recurring pattern
    @recurring.destroy

    redirect_back(
      fallback_location: root_path,
      notice: "Recurring transaction removed. Future projections have been deleted."
    )
  end

  def toggle_active
    @recurring.update(is_active: !@recurring.is_active)

    if @recurring.is_active?
      # Regenerate future transactions
      RecurringTransactions::GenerateService.call(@recurring)
      message = "Recurring transaction activated."
    else
      # Remove future transactions
      @recurring.generated_transactions.hypothetical.destroy_all
      message = "Recurring transaction paused."
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "recurring_transaction_#{@recurring.id}",
          partial: "recurring_transactions/recurring_transaction",
          locals: { recurring: @recurring }
        )
      end
      format.html { redirect_back(fallback_location: root_path, notice: message) }
    end
  end

  private

  def set_recurring_transaction
    @recurring = @account.recurring_transactions.find(params[:id])
  end

  def recurring_transaction_params
    params.require(:recurring_transaction).permit(
      :description, :amount, :frequency, :next_occurrence_date, :transaction_type,
      :category, :merchant_pattern, :amount_tolerance, :date_tolerance_days,
      :tolerance_type, :tolerance_percentage, :recurring_category, :projection_months, :is_active
    )
  end
end
