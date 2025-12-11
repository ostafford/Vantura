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
    @planned_transaction.planned_date = params[:date] ? Date.parse(params[:date]) : Date.current
    @planned_transaction.transaction_type = "expense"
    authorize @planned_transaction

    # If request is from calendar modal (Turbo Frame), render form partial
    if request.headers["Turbo-Frame"] == "planned-transaction-form"
      render layout: false
    end
  end

  def create
    @planned_transaction = current_user.planned_transactions.build(planned_transaction_params)
    authorize @planned_transaction

    if @planned_transaction.save
      # Broadcast Turbo Stream updates to calendar
      broadcast_calendar_updates(@planned_transaction)

      # If request is from calendar modal (Turbo Frame), return success response
      if request.headers["Turbo-Frame"] == "planned-transaction-form"
        # Turbo Stream template will handle frame removal and modal closing
        respond_to do |format|
          format.turbo_stream
        end
      else
        redirect_to @planned_transaction, notice: I18n.t("flash.planned_transactions.created")
      end
    else
      # Render form with errors within Turbo Frame for inline validation
      if request.headers["Turbo-Frame"] == "planned-transaction-form"
        render :new, status: :unprocessable_entity
      else
        render :new, status: :unprocessable_entity
      end
    end
  end

  def edit
    authorize @planned_transaction

    # If request is from calendar modal (Turbo Frame), render form partial
    if request.headers["Turbo-Frame"] == "planned-transaction-form"
      render layout: false
    end
  end

  def update
    authorize @planned_transaction
    if @planned_transaction.update(planned_transaction_params)
      # Broadcast Turbo Stream updates to calendar
      broadcast_calendar_updates(@planned_transaction)

      # If request is from calendar modal (Turbo Frame), return success response
      if request.headers["Turbo-Frame"] == "planned-transaction-form"
        # Turbo Stream template will handle frame removal and modal closing
        respond_to do |format|
          format.turbo_stream
        end
      else
        redirect_to @planned_transaction, notice: I18n.t("flash.planned_transactions.updated")
      end
    else
      # Render form with errors within Turbo Frame for inline validation
      if request.headers["Turbo-Frame"] == "planned-transaction-form"
        render :edit, status: :unprocessable_entity
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end

  def destroy
    authorize @planned_transaction
    # Store values before destroying
    planned_date = @planned_transaction.planned_date
    user = @planned_transaction.user

    # Store dates that will be affected before destroying
    affected_dates = [ planned_date ]
    if @planned_transaction.is_recurring?
      # Calculate affected dates for recurring transaction
      year = planned_date.year
      month = planned_date.month
      occurrences = @planned_transaction.occurrences_for_month(year, month)
      affected_dates = occurrences.map { |occ| occ[:date] }
    end

    @planned_transaction.destroy

    # Broadcast Turbo Stream updates to calendar
    broadcast_calendar_updates_after_destroy(user, affected_dates)

    # If request is from day-details turbo frame, return turbo_stream response
    if request.headers["Turbo-Frame"] == "day-details"
      # Store values for template
      @planned_date = planned_date
      @user = user
      respond_to do |format|
        format.turbo_stream
      end
    else
      redirect_to planned_transactions_path, notice: I18n.t("flash.planned_transactions.deleted")
    end
  end

  private

  def set_planned_transaction
    @planned_transaction = current_user.planned_transactions.find(params[:id])
  end

  def planned_transaction_params
    permitted = params.require(:planned_transaction).permit(
      :name,
      :description,
      :amount_cents,
      :amount_dollars,
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

    # Convert to hash to ensure clean parameter handling
    # ActionController::Parameters can have issues with delete operations
    result = permitted.to_h.symbolize_keys

    # Convert dollars to cents if amount_dollars is provided
    # Always remove amount_dollars from the hash to prevent "unknown attribute" errors
    # even if it's empty (empty strings are not "present" but still cause issues)
    if result.key?(:amount_dollars)
      if result[:amount_dollars].present?
        result[:amount_cents] = (result[:amount_dollars].to_f * 100).round
      end
      result.delete(:amount_dollars)
    end

    result
  end

  def broadcast_calendar_updates(planned_transaction)
    user = planned_transaction.user
    year = planned_transaction.planned_date.year
    month = planned_transaction.planned_date.month

    # Calculate affected dates (including recurrences)
    start_of_month = Date.new(year, month, 1)
    end_of_month = start_of_month.end_of_month

    # Recalculate projection using service
    result = CalendarProjectionService.calculate(
      user: user,
      start_date: start_of_month,
      end_date: end_of_month
    )

    projection_data = result[:projection_data]
    weekly_projection = result[:weekly_projection]
    monthly_projection = result[:monthly_projection]
    current_balance = result[:current_balance]

    # Get affected dates
    affected_dates = if planned_transaction.is_recurring?
                      occurrences = planned_transaction.occurrences_for_month(year, month)
                      occurrences.map { |occ| occ[:date] }
    else
                      [ planned_transaction.planned_date ]
    end

    # Broadcast calendar grid replacement
    # Get selected_date and view from session for client-side state
    selected_date = session[:calendar_selected_date] ? Date.parse(session[:calendar_selected_date]) : nil
    view = session[:calendar_view] || "month"

    Turbo::StreamsChannel.broadcast_replace_to(
      "user_#{user.id}_calendar",
      target: "calendar-grid",
      partial: "calendar/grid",
      locals: {
        year: year,
        month: month,
        projection_data: projection_data,
        selected_date: selected_date,
        view: view,
        start_of_month: start_of_month,
        end_of_month: end_of_month
      }
    )

    # Broadcast updates to affected day cells
    affected_dates.each do |date|
      raw_projection = projection_data[date]
      next unless raw_projection

      # Ensure projection has all required fields with defaults to prevent nil errors
      safe_projection = {
        balance_cents: 0,
        planned_count: 0,
        planned_total: 0,
        actual_count: 0,
        planned_transactions: [],
        actual_transactions: [],
        planned_income: 0,
        planned_expenses: 0,
        actual_income: 0,
        actual_expenses: 0,
        actual_total: 0
      }.merge(raw_projection)

      Turbo::StreamsChannel.broadcast_replace_to(
        "user_#{user.id}_calendar",
        target: "day-cell-#{date}",
        partial: "calendar/day_cell",
        locals: {
          date: date,
          projection: safe_projection,
          is_current_month: date.month == month && date.year == year,
          is_today: date == Date.current,
          is_selected: false # Will be determined by client-side state
        }
      )
    end

    # Broadcast projection bar update
    Turbo::StreamsChannel.broadcast_replace_to(
      "user_#{user.id}_calendar",
      target: "projection-bar",
      partial: "calendar/projection",
      locals: {
        current_balance: current_balance,
        weekly_projection: weekly_projection,
        monthly_projection: monthly_projection
      }
    )

    # Broadcast day-details updates only if a date is selected and it's affected
    # Check session for selected date to optimize broadcasts
    selected_date = session[:calendar_selected_date] ? Date.parse(session[:calendar_selected_date]) : nil

    if selected_date && affected_dates.include?(selected_date) && projection_data[selected_date]
      projection = projection_data[selected_date]

      # Update desktop day-details frame
      Turbo::StreamsChannel.broadcast_replace_to(
        "user_#{user.id}_calendar",
        target: "day-details",
        partial: "calendar/selected_day_frame",
        locals: {
          date: selected_date,
          projection: projection,
          frame_id: "day-details"
        }
      )

      # Update mobile day-details frame
      Turbo::StreamsChannel.broadcast_replace_to(
        "user_#{user.id}_calendar",
        target: "day-details-mobile",
        partial: "calendar/selected_day_frame",
        locals: {
          date: selected_date,
          projection: projection,
          frame_id: "day-details-mobile"
        }
      )
    end
  rescue => e
    Rails.logger.error "Failed to broadcast calendar updates: #{e.message}"
  end

  def broadcast_calendar_updates_after_destroy(user, affected_dates)
    return if affected_dates.empty?

    # Determine month from first affected date
    first_date = affected_dates.min
    year = first_date.year
    month = first_date.month

    start_of_month = Date.new(year, month, 1)
    end_of_month = start_of_month.end_of_month

    # Recalculate projection without the deleted transaction using service
    result = CalendarProjectionService.calculate(
      user: user,
      start_date: start_of_month,
      end_date: end_of_month
    )

    projection_data = result[:projection_data]
    weekly_projection = result[:weekly_projection]
    monthly_projection = result[:monthly_projection]
    current_balance = result[:current_balance]

    # Broadcast updates (same as create/update)
    Turbo::StreamsChannel.broadcast_replace_to(
      "user_#{user.id}_calendar",
      target: "calendar-grid",
      partial: "calendar/grid",
      locals: {
        year: year,
        month: month,
        projection_data: projection_data,
        start_of_month: start_of_month,
        end_of_month: end_of_month
      }
    )

    affected_dates.each do |date|
      next unless projection_data[date]

      Turbo::StreamsChannel.broadcast_replace_to(
        "user_#{user.id}_calendar",
        target: "day-cell-#{date}",
        partial: "calendar/day_cell",
        locals: {
          date: date,
          projection: projection_data[date],
          is_current_month: date.month == month && date.year == year,
          is_today: date == Date.current,
          is_selected: false
        }
      )
    end

    Turbo::StreamsChannel.broadcast_replace_to(
      "user_#{user.id}_calendar",
      target: "projection-bar",
      partial: "calendar/projection",
      locals: {
        current_balance: current_balance,
        weekly_projection: weekly_projection,
        monthly_projection: monthly_projection
      }
    )

    # Broadcast day-details updates only if a date is selected and it's affected
    # Check session for selected date to optimize broadcasts
    selected_date = session[:calendar_selected_date] ? Date.parse(session[:calendar_selected_date]) : nil

    if selected_date && affected_dates.include?(selected_date) && projection_data[selected_date]
      projection = projection_data[selected_date]

      # Update desktop day-details frame
      Turbo::StreamsChannel.broadcast_replace_to(
        "user_#{user.id}_calendar",
        target: "day-details",
        partial: "calendar/selected_day_frame",
        locals: {
          date: selected_date,
          projection: projection,
          frame_id: "day-details"
        }
      )

      # Update mobile day-details frame
      Turbo::StreamsChannel.broadcast_replace_to(
        "user_#{user.id}_calendar",
        target: "day-details-mobile",
        partial: "calendar/selected_day_frame",
        locals: {
          date: selected_date,
          projection: projection,
          frame_id: "day-details-mobile"
        }
      )
    end
  rescue => e
    Rails.logger.error "Failed to broadcast calendar updates after destroy: #{e.message}"
  end
end
