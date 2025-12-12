class ProjectsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, only: [ :show, :edit, :update, :destroy ]

  def index
    @projects = policy_scope(Project)
                      .includes(:owner, :members)
                      .order(created_at: :desc)
  end

  def show
    authorize @project
    # Prepare chart data for analytics
    prepare_project_analytics_data(@project)
  end

  def new
    @project = Project.new
    authorize @project
  end

  def create
    @project = current_user.owned_projects.build(project_params)
    authorize @project

    if @project.save
      flash[:notice] = I18n.t("flash.projects.created")
      respond_to do |format|
        format.turbo_stream { redirect_to @project, status: :see_other }
        format.html { redirect_to @project, notice: I18n.t("flash.projects.created") }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :new, status: :unprocessable_entity }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit
    authorize @project
  end

  def update
    authorize @project
    if @project.update(project_params)
      flash[:notice] = I18n.t("flash.projects.updated")
      respond_to do |format|
        format.turbo_stream { redirect_to @project, status: :see_other }
        format.html { redirect_to @project, notice: I18n.t("flash.projects.updated") }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :edit, status: :unprocessable_entity }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    authorize @project
    @project.destroy
    redirect_to projects_path, notice: I18n.t("flash.projects.deleted")
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:name, :description, :color)
  end

  def prepare_project_analytics_data(project)
    expenses = project.project_expenses.includes(:category, :paid_by_user, :expense_contributions)

    # Initialize empty data structures
    @category_breakdown_data = {}
    @spending_trend_data = {}
    @payment_history_data = {}
    @member_contributions_data = {}

    return if expenses.empty?

    # Category breakdown (using SQL grouping for performance)
    category_totals = expenses
      .where.not(category_id: nil)
      .joins(:category)
      .group("categories.id", "categories.name")
      .sum(:total_amount_cents)

    @category_breakdown_data = category_totals.transform_keys do |key|
      category_id, category_name = key.is_a?(Array) ? key : [key, nil]
      category_name || Category.find_by(id: category_id)&.name || "Unknown"
    end.transform_values { |cents| cents / 100.0 }

    # Spending over time (by expense_date, using SQL grouping)
    spending_by_date = expenses
      .group(:expense_date)
      .sum(:total_amount_cents)
      .sort_by { |date, _| date }
      .to_h

    @spending_trend_data = spending_by_date.transform_keys { |date| date.strftime("%Y-%m-%d") }.transform_values { |cents| cents / 100.0 }

    # Payment history (who paid, using SQL grouping)
    paid_by_totals = expenses
      .where.not(paid_by_user_id: nil)
      .joins(:paid_by_user)
      .group("users.id", "users.name", "users.email_address")
      .sum(:total_amount_cents)

    @payment_history_data = paid_by_totals.transform_keys do |key|
      user_id, name, email = key.is_a?(Array) ? key : [key, nil, nil]
      name.presence || email.presence || "User #{user_id}"
    end.transform_values { |cents| cents / 100.0 }

    # Member contributions breakdown (using SQL grouping)
    contribution_totals = expenses
      .joins(expense_contributions: :user)
      .group("users.id", "users.name", "users.email_address")
      .sum("expense_contributions.amount_cents")

    @member_contributions_data = contribution_totals.transform_keys do |key|
      user_id, name, email = key.is_a?(Array) ? key : [key, nil, nil]
      name.presence || email.presence || "User #{user_id}"
    end.transform_values { |cents| cents / 100.0 }
  end
end
