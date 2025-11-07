class RecurringCategoriesController < ApplicationController
  include AccountLoadable

  before_action :authorize_account_ownership!
  before_action :load_account
  before_action :set_recurring_category, only: [:destroy]

  def index
    @recurring_categories = @account.recurring_categories.order(:transaction_type, :name)
  end

  def create
    @recurring_category = @account.recurring_categories.new(recurring_category_params)

    if @recurring_category.save
      respond_to do |format|
        format.json { render json: { success: true, category: @recurring_category } }
        format.html { redirect_back(fallback_location: root_path, notice: "Category created successfully.") }
      end
    else
      respond_to do |format|
        format.json { render json: { success: false, errors: @recurring_category.errors.full_messages }, status: :unprocessable_entity }
        format.html { redirect_back(fallback_location: root_path, alert: "Error creating category: #{@recurring_category.errors.full_messages.join(', ')}") }
      end
    end
  end

  def destroy
    # Check if category is in use (case-insensitive)
    if @account.recurring_transactions.where("LOWER(recurring_category) = ?", @recurring_category.name.downcase).exists?
      respond_to do |format|
        format.json { render json: { success: false, error: "Cannot delete category that is in use" }, status: :unprocessable_entity }
        format.html { redirect_back(fallback_location: root_path, alert: "Cannot delete category that is in use by recurring transactions.") }
      end
      return
    end

    @recurring_category.destroy
    respond_to do |format|
      format.json { render json: { success: true } }
      format.html { redirect_back(fallback_location: root_path, notice: "Category deleted successfully.") }
    end
  end

  private

  def set_recurring_category
    @recurring_category = @account.recurring_categories.find(params[:id])
  end

  def recurring_category_params
    params.require(:recurring_category).permit(:name, :transaction_type)
  end
end

