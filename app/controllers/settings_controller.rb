require "bigdecimal"

class SettingsController < ApplicationController
  include Settings::Profile
  include Settings::Integrations::UpBank

  def show
    @user = Current.user
    @statistics = {
      accounts_count: @user.accounts.count,
      projects_count: user_projects_count
    }

    # Generate deletion token for this session
    session[:deletion_token] = SecureRandom.hex(16)
  end

  def update_profile
    update_user_profile
  end

  def update_up_bank_integration
    @up_bank_result = update_up_bank_token

    # Store notification in session for turbo_stream redirects (will be shown on redirected page)
    # This ensures the notification persists across Turbo.visit() navigation
    if @up_bank_result[:success] && @up_bank_result[:redirect_to]
      session[:up_bank_notification] = {
        type: :success,
        message: @up_bank_result[:message],
        sync_result: @up_bank_result[:sync_result]
      }
      flash[:notice] = @up_bank_result[:message] # Also set flash as fallback
    elsif !@up_bank_result[:success]
      flash[:alert] = @up_bank_result[:message]
    end

    respond_to do |format|
      format.turbo_stream
      format.html do
        if @up_bank_result[:success]
          redirect_to @up_bank_result[:redirect_to] || settings_path, notice: @up_bank_result[:message]
        elsif @up_bank_result[:render_errors]
          render :show, status: :unprocessable_entity
        else
          redirect_to settings_path, alert: @up_bank_result[:message]
        end
      end
    end
  end

  def update_account_goal
    @account = Current.user.accounts.find(params[:account_id])
    goal_result = build_goal_attributes
    @goal_form_state = goal_result[:form_state]

    respond_to do |format|
      if goal_result[:error]
        @goal_feedback = { type: :alert, message: goal_result[:error] }
        format.turbo_stream { render_goal_update(status: :unprocessable_entity) }
        format.html { redirect_to settings_path, alert: goal_result[:error] }
      elsif @account.update(goal_result[:attributes])
        @goal_feedback = { type: :notice, message: "Savings goal updated." }
        @goal_form_state = nil
        format.turbo_stream { render_goal_update }
        format.html { redirect_to settings_path, notice: "Savings goal updated." }
      else
        @goal_feedback = { type: :alert, message: @account.errors.full_messages.to_sentence }
        format.turbo_stream { render_goal_update(status: :unprocessable_entity) }
        format.html { redirect_to settings_path, alert: @goal_feedback[:message] }
      end
    end
  end

  def destroy
    @deletion_result = AccountDeletionService.call(Current.user, params[:confirmation_token], session[:deletion_token])

    respond_to do |format|
      format.turbo_stream
      format.html do
        if @deletion_result[:success]
          session.delete(:deletion_token)
          cookies.delete(:session_id)
          redirect_to new_session_path, notice: @deletion_result[:message]
        else
          redirect_to settings_path, alert: @deletion_result[:message]
        end
      end
    end
  end

  def build_goal_attributes
    permitted = params.require(:account).permit(
      :goal_mode,
      :target_savings_rate_percentage,
      :target_savings_amount_value
    )

    mode = permitted[:goal_mode]
    form_state = {
      mode: mode,
      rate_percentage: permitted[:target_savings_rate_percentage],
      amount_value: permitted[:target_savings_amount_value]
    }

    case mode
    when "break_even"
      {
        attributes: {
          target_savings_rate: 0,
          target_savings_amount: nil,
          goal_last_set_at: Time.current
        },
        form_state: form_state
      }
    when "rate"
      rate_decimal = parse_percentage(permitted[:target_savings_rate_percentage])
      return { error: "Enter a savings percentage between 0% and 30%.", form_state: form_state } if rate_decimal.nil?

      {
        attributes: {
          target_savings_rate: rate_decimal,
          target_savings_amount: nil,
          goal_last_set_at: Time.current
        },
        form_state: form_state
      }
    when "amount"
      amount_decimal = parse_amount(permitted[:target_savings_amount_value])
      return { error: "Enter a savings amount of $1 or more.", form_state: form_state } if amount_decimal.nil?

      {
        attributes: {
          target_savings_rate: 0,
          target_savings_amount: amount_decimal,
          goal_last_set_at: Time.current
        },
        form_state: form_state
      }
    else
      { error: "Select how you want to set your savings goal.", form_state: form_state }
    end
  rescue ActionController::ParameterMissing
    { error: "Select how you want to set your savings goal.", form_state: nil }
  end

  def parse_percentage(value)
    return nil if value.blank?

    normalized = sanitize_numeric(value)
    decimal = BigDecimal(normalized)
    return nil if decimal.negative? || decimal > 30

    (decimal / 100).round(4)
  rescue ArgumentError
    nil
  end

  def parse_amount(value)
    return nil if value.blank?

    normalized = sanitize_numeric(value)
    decimal = BigDecimal(normalized)
    return nil if decimal < 1

    decimal.round(2)
  rescue ArgumentError
    nil
  end

  def sanitize_numeric(value)
    value.to_s.strip.gsub(/[^\d.,-]/, "").tr(",", "")
  end

  def render_goal_update(status: :ok)
    render turbo_stream: turbo_stream.replace(
      helpers.dom_id(@account, "goal_section"),
      partial: "settings/account_goal_section",
      locals: {
        account: @account,
        goal_feedback: @goal_feedback,
        goal_form_state: @goal_form_state
      }
    ), status: status
  end
end
