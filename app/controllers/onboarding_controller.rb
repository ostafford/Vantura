class OnboardingController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_if_completed, only: [:connect_up_bank, :sync_progress]

  def connect_up_bank
    @user = current_user
  end

  def create_connection
    token = params[:token]&.strip

    if token.blank?
      flash[:error] = I18n.t("flash.onboarding.token_blank")
      redirect_to onboarding_connect_up_bank_path
      return
    end

    # Validate token format (basic check)
    unless token.start_with?("up:") && token.length > 20
      flash[:error] = I18n.t("flash.onboarding.token_invalid_format")
      redirect_to onboarding_connect_up_bank_path
      return
    end

    begin
      # Validate token with Up Bank API
      unless UpBankApiService.validate_token(token)
        flash[:error] = I18n.t("flash.onboarding.token_invalid")
        redirect_to onboarding_connect_up_bank_path
        return
      end

      # Token is valid, save it
      current_user.update!(up_bank_token: token)

      # Trigger initial sync with progress broadcasting
      SyncUpBankDataJob.perform_later(current_user, broadcast_progress: true)

      redirect_to onboarding_sync_progress_path
    rescue => e
      Rails.logger.error "Token validation failed: #{e.message}"
      flash[:error] = I18n.t("flash.onboarding.connection_failed")
      redirect_to onboarding_connect_up_bank_path
    end
  end

  def sync_progress
    @user = current_user
    # Check if sync is already complete
    if @user.last_synced_at.present? && @user.accounts.any?
      # Sync already completed, redirect to dashboard
      redirect_to dashboard_path
    end
  end

  def skip_connection
    redirect_to dashboard_path, notice: I18n.t("flash.onboarding.skip_connection")
  end

  private

  def redirect_if_completed
    # If user already has accounts synced, skip onboarding
    if current_user.accounts.any? && current_user.last_synced_at.present?
      redirect_to dashboard_path
    end
  end
end

