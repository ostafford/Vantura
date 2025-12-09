class DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_to_onboarding_if_needed, only: [ :index ]
  after_action :trigger_sync_if_needed, only: [ :index ]

  def index
    # Use Russian Doll caching
    @accounts = Rails.cache.fetch("user/#{current_user.id}/accounts", expires_in: 5.minutes) do
      current_user.accounts.to_a
    end

    # Calculate balance efficiently with caching (only TRANSACTIONAL accounts)
    @balance = Rails.cache.fetch("user/#{current_user.id}/balance", expires_in: 5.minutes) do
      current_user.accounts.transactional.sum(:balance_cents)
    end

    # Calculate stats for current month
    @stats = current_user.calculate_stats

    # Paginate transactions instead of loading all
    # Pagy 4.3: Use :offset for standard pagination
    @pagy, @recent_transactions = pagy(:offset, current_user.transactions.recent, items: 20)

    # Get upcoming planned transactions (next 7 days)
    @upcoming_planned = current_user.planned_transactions
      .where("planned_date >= ? AND planned_date <= ?", Date.current, 7.days.from_now)
      .order(:planned_date)
      .limit(5)

    # Get active projects with outstanding expenses
    @active_projects = current_user.projects
      .includes(:project_expenses)
      .limit(3)

    # Check if user needs to see insights banner (dismissible via localStorage)
    @show_insights = true # Can be enhanced to check localStorage or user preference
  end

  def sync
    return head :unauthorized unless current_user.has_up_bank_token?

    # Invalidate cache before syncing
    Rails.cache.delete("user/#{current_user.id}/accounts")
    Rails.cache.delete("user/#{current_user.id}/balance")

    SyncUpBankDataJob.perform_later(current_user)

    respond_to do |format|
      format.html { redirect_to dashboard_path, notice: I18n.t("flash.dashboard.sync_started") }
      format.json { render json: { status: "success", message: I18n.t("flash.dashboard.sync_started") }, status: :ok }
    end
  end

  private

  def redirect_to_onboarding_if_needed
    if current_user.needs_onboarding?
      redirect_to onboarding_connect_up_bank_path
    end
  end

  def trigger_sync_if_needed
    # Use database-backed throttling instead of session
    last_sync = current_user.webhook_events.maximum(:created_at)
    return if last_sync && last_sync > 5.minutes.ago
    return unless current_user.has_up_bank_token?

    SyncUpBankDataJob.perform_later(current_user)
  end
end
